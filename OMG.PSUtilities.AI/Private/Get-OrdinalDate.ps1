
function Get-OrdinalDate {
    <#
        .DESCRIPTION
        Returns the ordinal date (e.g., 1st, 2nd, 3rd) for a given date.

        .EXAMPLE
            Get-OrdinalDate
            19th August 2025
            1st January 2025
            3rd February 2025
    #>
    param([datetime]$Date = (Get-Date))
    $day = $Date.Day
    switch ($day) {
        { $_ -in 11..13 } { $suffix = "th" }
        default {
            switch ($day % 10) {
                1 { $suffix = "st" }
                2 { $suffix = "nd" }
                3 { $suffix = "rd" }
                default { $suffix = "th" }
            }
        }
    }
    "{0}{1} {2} {3}" -f $day, $suffix, $Date.ToString("MMMM"), $Date.Year
}