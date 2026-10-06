# =============================================================
# TODO: update comment based help
# DESCRIPTION NORMALIZATION HELPER
#
# Azure DevOps System.Description is an HTML field.
#
# Handles:
#
#   - HTML tags
#   - HTML entities
#   - Line-ending differences
#   - Whitespace differences
#
# Important:
#
# Do NOT use <[^>]+> because normal text such as:
#
#   a < b > c
#
# could incorrectly be treated as HTML.
# =============================================================

function ConvertTo-PSUNormalizedDescription {
    param (
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $normalized = $Value


    # ---------------------------------------------------------
    # Normalize line endings.
    # ---------------------------------------------------------

    $normalized = $normalized -replace "`r`n|`r|`n", "`n"


    # ---------------------------------------------------------
    # Convert common HTML block elements to whitespace/newline.
    # ---------------------------------------------------------

    $normalized = $normalized -replace '(?is)<br\s*/?>', "`n"

    $normalized = $normalized -replace '(?is)</p\s*>', "`n"

    $normalized = $normalized -replace '(?is)</div\s*>', "`n"

    $normalized = $normalized -replace '(?is)</li\s*>', "`n"


    # ---------------------------------------------------------
    # Remove actual-looking HTML tags only.
    #
    # Examples removed:
    #
    #   <p>
    #   </p>
    #   <div class="test">
    #   <strong>
    #   </strong>
    #   <br>
    #   <br/>
    #
    # Examples preserved:
    #
    #   a < b > c
    #   x < 10
    #   value > 5
    # ---------------------------------------------------------

    $normalized = [regex]::Replace(
        $normalized,
        '(?is)</?[a-z][a-z0-9]*(?:\s+[^>]*)?>',
        ' '
    )


    # ---------------------------------------------------------
    # Decode HTML entities.
    #
    # Examples:
    #
    #   &amp;
    #   &lt;
    #   &gt;
    #   &quot;
    #   &nbsp;
    # ---------------------------------------------------------

    $normalized = [System.Net.WebUtility]::HtmlDecode(
        $normalized
    )


    # ---------------------------------------------------------
    # Normalize whitespace.
    # ---------------------------------------------------------

    $normalized = [regex]::Replace(
        $normalized,
        '\s+',
        ' '
    )


    # ---------------------------------------------------------
    # Trim leading/trailing whitespace.
    # ---------------------------------------------------------

    return $normalized.Trim()
}