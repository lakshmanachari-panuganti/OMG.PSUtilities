# =============================================================
# TODO: update comment based help
# SAFE WORK ITEM FIELD HELPER
#
# Azure DevOps Work Items Batch API may omit fields whose value
# is not set.
#
# This helper safely retrieves a field without relying on
# missing-property behavior. This also makes the function safe
# when Set-StrictMode is enabled.
# =============================================================

function Get-PSUAdoWorkItemFieldValue {
    param (
        [AllowNull()]
        [object]$Fields,

        [Parameter(Mandatory)]
        [string]$FieldName
    )

    if ($null -eq $Fields) {
        return $null
    }

    $property = $Fields.PSObject.Properties[$FieldName]

    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}