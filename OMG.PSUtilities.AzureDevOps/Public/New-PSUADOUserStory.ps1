function New-PSUADOUserStory {
    <#
    .SYNOPSIS
        Creates a new User Story in Azure DevOps.

    .DESCRIPTION
        Creates a new User Story in Azure DevOps using the REST API.

        Duplicate checking can optionally be enabled using DuplicateCheck.

        Supported DuplicateCheck properties:

            Title
            AreaPath
            IterationPath
            Description

        DuplicateCheck uses AND logic. All specified properties must match
        for an existing User Story to be considered a duplicate.

        Description cannot be used as the only DuplicateCheck property.
        At least one of Title, AreaPath, or IterationPath must also be used.

        Closed and Removed User Stories are excluded from duplicate detection.

        Title, AreaPath, and IterationPath comparisons are case-insensitive.

        Description comparison is normalized to account for:

            - HTML formatting
            - HTML entities
            - Line-ending differences
            - Whitespace differences

        If a duplicate User Story is found, the existing User Story is
        returned and no new User Story is created.

        IsExisting indicates whether the returned User Story already existed:

            $true  = Existing User Story returned
            $false = New User Story created

    .PARAMETER Title
        The title of the User Story.

    .PARAMETER Description
        The description of the User Story.

    .PARAMETER AcceptanceCriteria
        The acceptance criteria of the User Story.

    .PARAMETER Priority
        Priority of the User Story.

        Valid values: 1 through 4.
        Default: 2.

    .PARAMETER StoryPoints
        Story points for the User Story.

    .PARAMETER AssignedTo
        User assigned to the User Story.

    .PARAMETER AreaPath
        Azure DevOps Area Path.

        Leading and trailing '\' characters are removed.

    .PARAMETER IterationPath
        Azure DevOps Iteration Path.

        Leading and trailing '\' characters are removed.

    .PARAMETER Tags
        Tags for the User Story.

        Comma-separated and semicolon-separated values are supported.

        Example:

            -Tags "Azure,DevOps,Automation"

        becomes:

            Azure; DevOps; Automation

    .PARAMETER DuplicateCheck
        Properties used to determine whether an existing User Story
        is a duplicate.

        Valid values:

            Title
            AreaPath
            IterationPath
            Description

        Multiple properties use AND logic.

        Examples:

            -DuplicateCheck Title

            -DuplicateCheck Title,AreaPath

            -DuplicateCheck Title,Description

            -DuplicateCheck Title,AreaPath,IterationPath,Description

        Description cannot be used by itself.

    .PARAMETER Project
        Azure DevOps project name.

        Both normal and URL-encoded project names are supported.

        Examples:

            MyProject

            My%20Project

    .PARAMETER Organization
        Azure DevOps organization name.

        Defaults to the ORGANIZATION environment variable.

    .PARAMETER PAT
        Azure DevOps Personal Access Token.

        Defaults to the PAT environment variable.

    .OUTPUTS
        PSCustomObject

        Properties:

            Id
            Title
            Description
            State
            Priority
            StoryPoints
            AssignedTo
            CreatedDate
            CreatedBy
            WorkItemType
            AreaPath
            IterationPath
            Url
            WebUrl
            IsExisting
            PSTypeName

    .NOTES
        Requires PowerShell 7.0 or later.

        Duplicate detection uses:

            1. WIQL server-side filtering
            2. Work Items Batch API
            3. Client-side normalized comparison

        If multiple matching User Stories exist, the User Story with the
        lowest Work Item ID is returned.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [string]$AcceptanceCriteria,

        [Parameter()]
        [ValidateRange(1, 4)]
        [int]$Priority = 2,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$StoryPoints,

        [Parameter()]
        [string]$AssignedTo,

        [Parameter()]
        [string]$AreaPath,

        [Parameter()]
        [string]$IterationPath,

        [Parameter()]
        [string]$Tags,

        [Parameter()]
        [ValidateSet(
            'Title',
            'AreaPath',
            'IterationPath',
            'Description'
        )]
        [string[]]$DuplicateCheck,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization = $env:ORGANIZATION,

        [Parameter()]
        [string]$PAT = $env:PAT
    )

    begin {

        # =============================================================
        # PARAMETER TRACE
        # =============================================================

        Write-PSUAdoParameterTrace `
            -Invocation $MyInvocation `
            -BoundParameters $PSBoundParameters


        # =============================================================
        # CONNECTION VALIDATION
        # =============================================================

        Confirm-PSUAdoConnectionParameter `
            -Organization $Organization `
            -PAT $PAT


        # =============================================================
        # AUTHENTICATION
        # =============================================================

        $headers = Get-PSUAdoAuthHeader -PAT $PAT

        $headers['Content-Type'] = 'application/json-patch+json'


        # =============================================================
        # PROJECT NORMALIZATION
        # =============================================================

        $plainProject = [uri]::UnescapeDataString($Project)

        $escapedProject = [uri]::EscapeDataString($plainProject)


        # =============================================================
        # AREA PATH NORMALIZATION
        # =============================================================

        if (-not [string]::IsNullOrWhiteSpace($AreaPath)) {
            $AreaPath = $AreaPath.Trim([char]'\')
        }


        # =============================================================
        # ITERATION PATH NORMALIZATION
        # =============================================================

        if (-not [string]::IsNullOrWhiteSpace($IterationPath)) {
            $IterationPath = $IterationPath.Trim([char]'\')
        }


        # =============================================================
        # TAG NORMALIZATION
        # =============================================================

        if (-not [string]::IsNullOrWhiteSpace($Tags)) {

            $Tags = (
                $Tags -split '\s*[,;]\s*' |
                    ForEach-Object {
                        $_.Trim()
                    } |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_)
                    }
            ) -join '; '
        }


        # =============================================================
        # NORMALIZE INPUT DESCRIPTION ONCE
        # =============================================================

        $normalizedInputDescription = ConvertTo-PSUNormalizedDescription -Value $Description
    }


    process {

        try {

            # =========================================================
            # DUPLICATE CHECK
            # =========================================================

            if ($DuplicateCheck) {

                Write-Verbose "Duplicate checking enabled."

                Write-Verbose `
                    "Duplicate check properties: $($DuplicateCheck -join ', ')"


                # =====================================================
                # VALIDATE DUPLICATE CHECK INPUTS
                # =====================================================

                foreach ($property in $DuplicateCheck) {

                    switch ($property) {

                        'Title' {

                            if ([string]::IsNullOrWhiteSpace($Title)) {

                                throw `
                                    "DuplicateCheck includes 'Title', but Title was not provided."
                            }
                        }

                        'Description' {

                            if ([string]::IsNullOrWhiteSpace($Description)) {

                                throw `
                                    "DuplicateCheck includes 'Description', but Description was not provided."
                            }
                        }

                        'AreaPath' {

                            if ([string]::IsNullOrWhiteSpace($AreaPath)) {

                                throw `
                                    "DuplicateCheck includes 'AreaPath', but AreaPath was not provided."
                            }
                        }

                        'IterationPath' {

                            if ([string]::IsNullOrWhiteSpace($IterationPath)) {

                                throw `
                                    "DuplicateCheck includes 'IterationPath', but IterationPath was not provided."
                            }
                        }
                    }
                }


                # =====================================================
                # DESCRIPTION CANNOT BE USED ALONE
                #
                # Prevents a potentially project-wide User Story scan.
                # =====================================================

                $hasNarrowingProperty =
                ($DuplicateCheck -contains 'Title') -or
                ($DuplicateCheck -contains 'AreaPath') -or
                ($DuplicateCheck -contains 'IterationPath')


                if (
                    ($DuplicateCheck -contains 'Description') -and
                    (-not $hasNarrowingProperty)
                ) {

                    throw @"
DuplicateCheck cannot use 'Description' by itself.

When using Description for duplicate detection, specify at least one
of the following properties as well:

    Title
    AreaPath
    IterationPath

Examples:

    -DuplicateCheck Title,Description

    -DuplicateCheck AreaPath,Description

    -DuplicateCheck IterationPath,Description
"@
                }


                # =====================================================
                # BUILD WIQL CONDITIONS
                # =====================================================

                $wiqlConditions = @(
                    "[System.TeamProject] = '$($plainProject.Replace("'", "''"))'"

                    "[System.WorkItemType] = 'User Story'"

                    # Closed and Removed stories do not prevent creation
                    # of a new active User Story.
                    "[System.State] NOT IN ('Closed','Removed')"
                )


                # =====================================================
                # TITLE CONDITION
                # =====================================================

                if ($DuplicateCheck -contains 'Title') {

                    $escapedTitle =
                    $Title.Replace("'", "''")

                    $wiqlConditions +=
                    "[System.Title] = '$escapedTitle'"
                }


                # =====================================================
                # AREA PATH CONDITION
                # =====================================================

                if ($DuplicateCheck -contains 'AreaPath') {

                    $escapedAreaPath =
                    $AreaPath.Replace("'", "''")

                    $wiqlConditions +=
                    "[System.AreaPath] = '$escapedAreaPath'"
                }


                # =====================================================
                # ITERATION PATH CONDITION
                # =====================================================

                if ($DuplicateCheck -contains 'IterationPath') {

                    $escapedIterationPath =
                    $IterationPath.Replace("'", "''")

                    $wiqlConditions +=
                    "[System.IterationPath] = '$escapedIterationPath'"
                }


                # =====================================================
                # BUILD WIQL
                # =====================================================

                $wiql = @"
SELECT [System.Id]
FROM WorkItems
WHERE $($wiqlConditions -join "`nAND ")
ORDER BY [System.Id]
"@


                Write-Verbose "Duplicate check WIQL:"
                Write-Verbose $wiql


                # =====================================================
                # WIQL API REQUEST
                # =====================================================

                $wiqlUri =
                "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/wiql?api-version=7.1"


                $wiqlHeaders =
                Get-PSUAdoAuthHeader -PAT $PAT

                $wiqlHeaders['Content-Type'] = 'application/json'


                $wiqlBody = @{
                    query = $wiql
                } |
                    ConvertTo-Json -Depth 3


                $wiqlResponse = Invoke-RestMethod `
                    -Uri $wiqlUri `
                    -Headers $wiqlHeaders `
                    -Method Post `
                    -Body $wiqlBody `
                    -ErrorAction Stop


                # =====================================================
                # GET AND SORT CANDIDATE IDS
                #
                # Explicit sorting ensures that selection does not
                # depend on API response order.
                # =====================================================

                $candidateIds = @(
                    $wiqlResponse.workItems |
                        ForEach-Object {
                            [int]$_.id
                        } |
                        Sort-Object
                )


                Write-Verbose `
                    "Duplicate check returned $($candidateIds.Count) candidate User Story(s)."


                # =====================================================
                # RETRIEVE CANDIDATE WORK ITEMS
                # =====================================================

                if ($candidateIds.Count -gt 0) {

                    $fieldsToRetrieve = @(
                        'System.Id'
                        'System.Title'
                        'System.Description'
                        'System.State'
                        'Microsoft.VSTS.Common.Priority'
                        'Microsoft.VSTS.Scheduling.StoryPoints'
                        'System.AssignedTo'
                        'System.CreatedDate'
                        'System.CreatedBy'
                        'System.WorkItemType'
                        'System.AreaPath'
                        'System.IterationPath'
                    )


                    $batchUri =
                    "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitemsbatch?api-version=7.1"


                    # =================================================
                    # PROCESS MAXIMUM 200 IDS PER BATCH
                    # =================================================

                    for (
                        $offset = 0;
                        $offset -lt $candidateIds.Count;
                        $offset += 200
                    ) {

                        $batchEnd = [Math]::Min(
                            $offset + 199,
                            $candidateIds.Count - 1
                        )


                        $batchIds = @(
                            $candidateIds[$offset..$batchEnd]
                        )


                        $batchBody = @{
                            ids    = $batchIds
                            fields = $fieldsToRetrieve
                        } |
                            ConvertTo-Json -Depth 5


                        $batchHeaders =
                        Get-PSUAdoAuthHeader -PAT $PAT

                        $batchHeaders['Content-Type'] = 'application/json'


                        $batchResponse = Invoke-RestMethod `
                            -Uri $batchUri `
                            -Headers $batchHeaders `
                            -Method Post `
                            -Body $batchBody `
                            -ErrorAction Stop


                        # =================================================
                        # SORT BATCH RESPONSE BY WORK ITEM ID
                        #
                        # Do not rely on Work Items Batch API response
                        # ordering.
                        # =================================================

                        $sortedCandidates = @(
                            $batchResponse.value |
                                Sort-Object -Property id
                        )


                        foreach ($candidate in $sortedCandidates) {

                            $isDuplicate = $true


                            # =================================================
                            # SAFE FIELD RETRIEVAL
                            #
                            # Missing optional fields become $null instead
                            # of causing PropertyNotFoundException under
                            # Set-StrictMode.
                            # =================================================

                            $candidateTitle =
                            Get-PSUAdoWorkItemFieldValue `
                                -Fields $candidate.fields `
                                -FieldName 'System.Title'


                            $candidateDescription =
                            Get-PSUAdoWorkItemFieldValue `
                                -Fields $candidate.fields `
                                -FieldName 'System.Description'


                            $candidateAreaPath =
                            Get-PSUAdoWorkItemFieldValue `
                                -Fields $candidate.fields `
                                -FieldName 'System.AreaPath'


                            $candidateIterationPath =
                            Get-PSUAdoWorkItemFieldValue `
                                -Fields $candidate.fields `
                                -FieldName 'System.IterationPath'


                            # =================================================
                            # COMPARE REQUESTED DUPLICATE PROPERTIES
                            #
                            # AND logic:
                            #
                            # Every requested property must match.
                            # =================================================

                            foreach ($property in $DuplicateCheck) {

                                switch ($property) {

                                    # -------------------------------------------------
                                    # TITLE
                                    #
                                    # Case-insensitive comparison.
                                    # -------------------------------------------------

                                    'Title' {

                                        if (
                                            $candidateTitle -ine $Title
                                        ) {

                                            $isDuplicate = $false
                                        }
                                    }


                                    # -------------------------------------------------
                                    # AREA PATH
                                    #
                                    # Case-insensitive comparison.
                                    # -------------------------------------------------

                                    'AreaPath' {

                                        if (
                                            $candidateAreaPath -ine $AreaPath
                                        ) {

                                            $isDuplicate = $false
                                        }
                                    }


                                    # -------------------------------------------------
                                    # ITERATION PATH
                                    #
                                    # Case-insensitive comparison.
                                    # -------------------------------------------------

                                    'IterationPath' {

                                        if (
                                            $candidateIterationPath -ine $IterationPath
                                        ) {

                                            $isDuplicate = $false
                                        }
                                    }


                                    # -------------------------------------------------
                                    # DESCRIPTION
                                    #
                                    # Normalize the stored ADO HTML and compare
                                    # against normalized input.
                                    #
                                    # Case-insensitive comparison.
                                    # -------------------------------------------------

                                    'Description' {

                                        $normalizedExistingDescription =
                                        ConvertTo-PSUNormalizedDescription `
                                            -Value $candidateDescription


                                        if (
                                            $normalizedExistingDescription -ine
                                            $normalizedInputDescription
                                        ) {

                                            $isDuplicate = $false
                                        }
                                    }
                                }


                                # -------------------------------------------------
                                # Stop comparison as soon as a mismatch is found.
                                # -------------------------------------------------

                                if (-not $isDuplicate) {
                                    break
                                }
                            }


                            # =================================================
                            # DUPLICATE FOUND
                            # =================================================

                            if ($isDuplicate) {

                                Write-Verbose `
                                    "Duplicate User Story found. Work Item ID: $($candidate.id)"

                                Write-Verbose `
                                    "No new User Story will be created."


                                # -------------------------------------------------
                                # Safely retrieve optional fields.
                                # -------------------------------------------------

                                $candidateAssignedTo =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'System.AssignedTo'


                                $candidateStoryPoints =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'Microsoft.VSTS.Scheduling.StoryPoints'


                                $candidatePriority =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'Microsoft.VSTS.Common.Priority'


                                $candidateState =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'System.State'


                                $candidateCreatedDate =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'System.CreatedDate'


                                $candidateCreatedBy =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'System.CreatedBy'


                                $candidateWorkItemType =
                                Get-PSUAdoWorkItemFieldValue `
                                    -Fields $candidate.fields `
                                    -FieldName 'System.WorkItemType'


                                $candidateAssignedToName =
                                if ($null -ne $candidateAssignedTo) {
                                    $candidateAssignedTo.displayName
                                } else {
                                    $null
                                }


                                $candidateCreatedByName =
                                if ($null -ne $candidateCreatedBy) {
                                    $candidateCreatedBy.displayName
                                } else {
                                    $null
                                }


                                # -------------------------------------------------
                                # Construct WebUrl directly.
                                #
                                # Do not depend on _links from the batch response.
                                # -------------------------------------------------

                                $webUrl =
                                "https://dev.azure.com/$Organization/$escapedProject/_workitems/edit/$($candidate.id)"


                                # -------------------------------------------------
                                # Return existing User Story.
                                # -------------------------------------------------

                                [PSCustomObject]@{
                                    Id            = $candidate.id
                                    Title         = $candidateTitle
                                    Description   = $candidateDescription
                                    State         = $candidateState
                                    Priority      = $candidatePriority
                                    StoryPoints   = $candidateStoryPoints
                                    AssignedTo    = $candidateAssignedToName
                                    CreatedDate   = $candidateCreatedDate
                                    CreatedBy     = $candidateCreatedByName
                                    WorkItemType  = $candidateWorkItemType
                                    AreaPath      = $candidateAreaPath
                                    IterationPath = $candidateIterationPath
                                    Url           = $candidate.url
                                    WebUrl        = $webUrl
                                    IsExisting    = $true
                                    PSTypeName    = 'PSU.ADO.UserStory'
                                }


                                # -------------------------------------------------
                                # Candidate IDs and batch responses are both
                                # sorted by ID. Therefore the first match is
                                # deterministic and represents the lowest
                                # matching Work Item ID.
                                # -------------------------------------------------

                                return
                            }
                        }
                    }
                }


                Write-Verbose "No duplicate User Story found."
            }


            # =============================================================
            # CREATE NEW USER STORY
            # =============================================================

            $fields = @(
                @{
                    op    = "add"
                    path  = "/fields/System.Title"
                    value = $Title
                },

                @{
                    op    = "add"
                    path  = "/fields/System.Description"
                    value = $Description
                },

                @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Common.Priority"
                    value = $Priority
                }
            )


            # =============================================================
            # ACCEPTANCE CRITERIA
            # =============================================================

            if (-not [string]::IsNullOrWhiteSpace($AcceptanceCriteria)) {

                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria"
                    value = $AcceptanceCriteria
                }
            }


            # =============================================================
            # STORY POINTS
            #
            # Use ContainsKey so explicitly supplied 0 is not silently
            # treated as "not supplied".
            # =============================================================

            if ($PSBoundParameters.ContainsKey('StoryPoints')) {

                $fields += @{
                    op    = "add"
                    path  = "/fields/Microsoft.VSTS.Scheduling.StoryPoints"
                    value = $StoryPoints
                }
            }


            # =============================================================
            # ASSIGNED TO
            # =============================================================

            if (-not [string]::IsNullOrWhiteSpace($AssignedTo)) {

                $fields += @{
                    op    = "add"
                    path  = "/fields/System.AssignedTo"
                    value = $AssignedTo
                }
            }


            # =============================================================
            # AREA PATH
            # =============================================================

            if (-not [string]::IsNullOrWhiteSpace($AreaPath)) {

                $fields += @{
                    op    = "add"
                    path  = "/fields/System.AreaPath"
                    value = $AreaPath
                }
            }


            # =============================================================
            # ITERATION PATH
            # =============================================================

            if (-not [string]::IsNullOrWhiteSpace($IterationPath)) {

                $fields += @{
                    op    = "add"
                    path  = "/fields/System.IterationPath"
                    value = $IterationPath
                }
            }


            # =============================================================
            # TAGS
            # =============================================================

            if (-not [string]::IsNullOrWhiteSpace($Tags)) {

                $fields += @{
                    op    = "add"
                    path  = "/fields/System.Tags"
                    value = $Tags
                }
            }


            # =============================================================
            # CONVERT JSON PATCH DOCUMENT
            #
            # PowerShell 7+ supports -AsArray.
            # =============================================================

            $body = $fields |
                ConvertTo-Json -Depth 3 -AsArray


            # =============================================================
            # CREATE USER STORY API
            # =============================================================

            $uri =
            "https://dev.azure.com/$Organization/$escapedProject/_apis/wit/workitems/`$User%20Story?api-version=7.1-preview.3"


            Write-Verbose `
                "Creating User Story in project: $plainProject"


            Write-Verbose `
                "API URI: $uri"


            $response = Invoke-RestMethod `
                -Uri $uri `
                -Headers $headers `
                -Method Post `
                -Body $body `
                -ErrorAction Stop


            # =============================================================
            # SAFELY READ CREATED WORK ITEM FIELDS
            #
            # These normally exist, but using the same helper keeps the
            # output resilient under StrictMode.
            # =============================================================

            $responseTitle =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.Title'


            $responseDescription =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.Description'


            $responseState =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.State'


            $responsePriority =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'Microsoft.VSTS.Common.Priority'


            $responseStoryPoints =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'Microsoft.VSTS.Scheduling.StoryPoints'


            $responseAssignedTo =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.AssignedTo'


            $responseCreatedDate =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.CreatedDate'


            $responseCreatedBy =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.CreatedBy'


            $responseWorkItemType =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.WorkItemType'


            $responseAreaPath =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.AreaPath'


            $responseIterationPath =
            Get-PSUAdoWorkItemFieldValue `
                -Fields $response.fields `
                -FieldName 'System.IterationPath'


            $responseAssignedToName =
            if ($null -ne $responseAssignedTo) {
                $responseAssignedTo.displayName
            } else {
                $null
            }


            $responseCreatedByName =
            if ($null -ne $responseCreatedBy) {
                $responseCreatedBy.displayName
            } else {
                $null
            }


            # =============================================================
            # RETURN NEW USER STORY
            # =============================================================

            [PSCustomObject]@{
                Id            = $response.id
                Title         = $responseTitle
                Description   = $responseDescription
                State         = $responseState
                Priority      = $responsePriority
                StoryPoints   = $responseStoryPoints
                AssignedTo    = $responseAssignedToName
                CreatedDate   = $responseCreatedDate
                CreatedBy     = $responseCreatedByName
                WorkItemType  = $responseWorkItemType
                AreaPath      = $responseAreaPath
                IterationPath = $responseIterationPath
                Url           = $response.url
                WebUrl        = $response._links.html.href
                IsExisting    = $false
                PSTypeName    = 'PSU.ADO.UserStory'
            }
        } catch {

            # =============================================================
            # RETURN ORIGINAL ERROR
            # =============================================================

            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}