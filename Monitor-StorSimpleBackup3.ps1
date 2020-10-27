#requires -Version 4
#requires -RunAsAdministrator
#requires -Modules Azure


<# 
Script to report on StorSimple Backups 
Script by Sam Boutros 
    9 November, 2015 - v1.0
    7 June 2016 - v1.1 
        Cosmetic updates: regions, splatting 
        Azure authentication via certificate (publish settings)       
#>


#region Input
$SubscriptionName      = 'StorSimpleLong-Production'
$StorSimpleManagerName = 'long-westeurope'
$RegistrationKey       = '1937551030888174599:dmkGxxxxxxxxN0MHRQw/R5Q==#0f5667d16dc3c1a4'
$TargetDeviceName      = '8100-long'
$SubscriptionID        = '3948c56xxxxxxxxxxxxebb1167fc'
$PublishSettingsFile   = 'C:\Sandbox\xxxxx-10-27-2015-credentials.publishsettings'
                       # To get the publishsettings file use the cmdlets: Add-AzureAccount; Get-AzurePublishSettingsFile

$Duration              = 7 # Number of days to report on backups for
$LogFile               = "C:\Sandbox\logs\StorSimpleBackupLog-$(Get-Date -format yyyy-MM-dd_HH-mm-sstt).txt"
$HTMLFile              = "C:\Sandbox\logs\StorSimpleBackupLog-$(Get-Date -format yyyy-MM-dd_HH-mm-sstt).htm"
$EmailSender           = 'StorSimple Backup Monitor <DoNotReply@xxxxxx.com>'
$EmailRecipients       = @( # Add recipients email addresses below:
                            # 'Someone Else <Someone.else@xxxxxxx.com>'
                            'Sam Boutros <sboutros@vertitechit.com>'
                          )
$SMTPServer            = 'mail.mymailrelay.com'
#endregion


function Log {
<# 
 .Synopsis
  Function to log input string to file and display it to screen

 .Description
  Function to log input string to file and display it to screen. Log entries in the log file are time stamped. Function allows for displaying text to screen in different colors.

 .Parameter String
  The string to be displayed to the screen and saved to the log file

 .Parameter Color
  The color in which to display the input string on the screen
  Default is White
  Valid options are
    Black
    Blue
    Cyan
    DarkBlue
    DarkCyan
    DarkGray
    DarkGreen
    DarkMagenta
    DarkRed
    DarkYellow
    Gray
    Green
    Magenta
    Red
    White
    Yellow

 .Parameter LogFile
  Path to the file where the input string should be saved.
  Example: c:\log.txt
  If absent, the input string will be displayed to the screen only and not saved to log file

 .Example
  Log -String "Hello World" -Color Yellow -LogFile c:\log.txt
  This example displays the "Hello World" string to the console in yellow, and adds it as a new line to the file c:\log.txt
  If c:\log.txt does not exist it will be created.
  Log entries in the log file are time stamped. Sample output:
    2014.08.06 06:52:17 AM: Hello World

 .Example
  Log "$((Get-Location).Path)" Cyan
  This example displays current path in Cyan, and does not log the displayed text to log file.

 .Example 
  "$((Get-Process | select -First 1).name) process ID is $((Get-Process | select -First 1).id)" | log -color DarkYellow
  Sample output of this example:
    "MDM process ID is 4492" in dark yellow

 .Example
  log "Found",(Get-ChildItem -Path .\ -File).Count,"files in folder",(Get-Item .\).FullName Green,Yellow,Green,Cyan .\mylog.txt
  Sample output will look like:
    Found 520 files in folder D:\Sandbox - and will have the listed foreground colors

 .Link
  https://superwidgets.wordpress.com/category/powershell/

 .Notes
  Function by Sam Boutros
  v1.0 - 08/06/2014
  v1.1 - 12/01/2014 - added multi-color display in the same line

#>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')] 
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeLine=$true,
                   ValueFromPipeLineByPropertyName=$true,
                   Position=0)]
            [String[]]$String, 
        [Parameter(Mandatory=$false,
                   Position=1)]
            [ValidateSet("Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta","DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow")]
            [String[]]$Color = "Green", 
        [Parameter(Mandatory=$false,
                   Position=2)]
            [String]$LogFile,
        [Parameter(Mandatory=$false,
                   Position=3)]
            [Switch]$NoNewLine
    )

    if ($String.Count -gt 1) {
        $i=0
        foreach ($item in $String) {
            if ($Color[$i]) { $col = $Color[$i] } else { $col = "White" }
            Write-Host "$item " -ForegroundColor $col -NoNewline
            $i++
        }
        if (-not ($NoNewLine)) { Write-Host " " }
    } else { 
        if ($NoNewLine) { Write-Host $String -ForegroundColor $Color[0] -NoNewline }
            else { Write-Host $String -ForegroundColor $Color[0] }
    }

    if ($LogFile.Length -gt 2) {
        "$(Get-Date -format "yyyy.MM.dd hh:mm:ss tt"): $($String -join " ")" | Out-File -Filepath $Logfile -Append 
    } else {
        Write-Verbose "Log: Missing -LogFile parameter. Will not save input string to log file.."
    }
}


function ConvertTo-EnhancedHTML {
<#
Function by Don Jones - Powershell.org

.SYNOPSIS
Provides an enhanced version of the ConvertTo-HTML command that includes
inserting an embedded CSS style sheet, JQuery, and JQuery Data Tables for
interactivity. Intended to be used with HTML fragments that are produced
by ConvertTo-EnhancedHTMLFragment. This command does not accept pipeline
input.

.PARAMETER jQueryURI
A Uniform Resource Indicator (URI) pointing to the location of the 
jQuery script file. You can download jQuery from www.jquery.com; you should
host the script file on a local intranet Web server and provide a URI
that starts with http:// or https://. Alternately, you can also provide
a file system path to the script file, although this may create security
issues for the Web browser in some configurations.

Tested with v1.8.2.

Defaults to http://ajax.aspnetcdn.com/ajax/jQuery/jquery-1.8.2.min.js, which
will pull the file from Microsoft's ASP.NET Content Delivery Network.

.PARAMETER jQueryDataTableURI
A Uniform Resource Indicator (URI) pointing to the location of the 
jQuery Data Table script file. You can download this from www.datatables.net;
you should host the script file on a local intranet Web server and provide a URI
that starts with http:// or https://. Alternately, you can also provide
a file system path to the script file, although this may create security
issues for the Web browser in some configurations.

Tested with jQuery DataTable v1.9.4

Defaults to http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.3/jquery.dataTables.min.js,
which will pull the file from Microsoft's ASP.NET Content Delivery Network.

.PARAMETER CssStyleSheet
The CSS style sheet content - not a file name. If you have a CSS file,
you can load it into this parameter as follows:

    -CSSStyleSheet (Get-Content MyCSSFile.css)

Alternately, you may link to a Web server-hosted CSS file by using the
-CssUri parameter.

.PARAMETER CssUri
A Uniform Resource Indicator (URI) to a Web server-hosted CSS file.
Must start with either http:// or https://. If you omit this, you
can still provide an embedded style sheet, which makes the resulting
HTML page more standalone. To provide an embedded style sheet, use
the -CSSStyleSheet parameter.

.PARAMETER Title
A plain-text title that will be displayed in the Web browser's window
title bar. Note that not all browsers will display this.


.PARAMETER PreContent
Raw HTML to insert before all HTML fragments. Use this to specify a main
title for the report:

    -PreContent "<H1>My HTML Report</H1>"

.PARAMETER PostContent
Raw HTML to insert after all HTML fragments. Use this to specify a 
report footer:

    -PostContent "Created on $(Get-Date)"

.PARAMETER HTMLFragments
One or more HTML fragments, as produced by ConvertTo-EnhancedHTMLFragment.

    -HTMLFragments $part1,$part2,$part3
#>
    [CmdletBinding()]
    param(
        [string]$jQueryURI = 'http://ajax.aspnetcdn.com/ajax/jQuery/jquery-1.8.2.min.js',
        [string]$jQueryDataTableURI = 'http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.3/jquery.dataTables.min.js',
        [Parameter(ParameterSetName='CSSContent')][string[]]$CssStyleSheet,
        [Parameter(ParameterSetName='CSSURI')][string[]]$CssUri,
        [string]$Title = 'Report',
        [string]$PreContent,
        [string]$PostContent,
        [Parameter(Mandatory=$True)][string[]]$HTMLFragments
    )


    <#
        Add CSS style sheet. If provided in -CssUri, add a <link> element.
        If provided in -CssStyleSheet, embed in the <head> section.
        Note that BOTH may be supplied - this is legitimate in HTML.
    #>
    Write-Verbose "Making CSS style sheet"
    $stylesheet = ""
    if ($PSBoundParameters.ContainsKey('CssUri')) {
        $stylesheet = "<link rel=`"stylesheet`" href=`"$CssUri`" type=`"text/css`" />"
    }
    if ($PSBoundParameters.ContainsKey('CssStyleSheet')) {
        $stylesheet = "<style>$CssStyleSheet</style>" | Out-String
    }


    <#
        Create the HTML tags for the page title, and for
        our main javascripts.
    #>
    Write-Verbose "Creating <TITLE> and <SCRIPT> tags"
    $titletag = ""
    if ($PSBoundParameters.ContainsKey('title')) {
        $titletag = "<title>$title</title>"
    }
    $script += "<script type=`"text/javascript`" src=`"$jQueryURI`"></script>`n<script type=`"text/javascript`" src=`"$jQueryDataTableURI`"></script>"


    <#
        Render supplied HTML fragments as one giant string
    #>
    Write-Verbose "Combining HTML fragments"
    $body = $HTMLFragments | Out-String


    <#
        If supplied, add pre- and post-content strings
    #>
    Write-Verbose "Adding Pre and Post content"
    if ($PSBoundParameters.ContainsKey('precontent')) {
        $body = "$PreContent`n$body"
    }
    if ($PSBoundParameters.ContainsKey('postcontent')) {
        $body = "$body`n$PostContent"
    }


    <#
        Add a final script that calls the datatable code
        We dynamic-ize all tables with the .enhancedhtml-dynamic-table
        class, which is added by ConvertTo-EnhancedHTMLFragment.
    #>
    Write-Verbose "Adding interactivity calls"
    $datatable = ""
    $datatable = "<script type=`"text/javascript`">"
    $datatable += '$(document).ready(function () {'
    $datatable += "`$('.enhancedhtml-dynamic-table').dataTable();"
    $datatable += '} );'
    $datatable += "</script>"


    <#
        Datatables expect a <thead> section containing the
        table header row; ConvertTo-HTML doesn't produce that
        so we have to fix it.
    #>
    Write-Verbose "Fixing table HTML"
    $body = $body -replace '<tr><th>','<thead><tr><th>'
    $body = $body -replace '</th></tr>','</th></tr></thead>'


    <#
        Produce the final HTML. We've more or less hand-made
        the <head> amd <body> sections, but we let ConvertTo-HTML
        produce the other bits of the page.
    #>
    Write-Verbose "Producing final HTML"
    ConvertTo-HTML -Head "$stylesheet`n$titletag`n$script`n$datatable" -Body $body  
    Write-Debug "Finished producing final HTML"


}


function ConvertTo-EnhancedHTMLFragment {
<#
Function by Don Jones - Powershell.org

.SYNOPSIS
Creates an HTML fragment (much like ConvertTo-HTML with the -Fragment switch
that includes CSS class names for table rows, CSS class and ID names for the
table, and wraps the table in a <DIV> tag that has a CSS class and ID name.

.PARAMETER InputObject
The object to be converted to HTML. You cannot select properties using this
command; precede this command with Select-Object if you need a subset of
the objects' properties.

.PARAMETER EvenRowCssClass
The CSS class name applied to even-numbered <TR> tags. Optional, but if you
use it you must also include -OddRowCssClass.

.PARAMETER OddRowCssClass
The CSS class name applied to odd-numbered <TR> tags. Optional, but if you 
use it you must also include -EvenRowCssClass.

.PARAMETER TableCssID
Optional. The CSS ID name applied to the <TABLE> tag.

.PARAMETER DivCssID
Optional. The CSS ID name applied to the <DIV> tag which is wrapped around the table.

.PARAMETER TableCssClass
Optional. The CSS class name to apply to the <TABLE> tag.

.PARAMETER DivCssClass
Optional. The CSS class name to apply to the wrapping <DIV> tag.

.PARAMETER As
Must be 'List' or 'Table.' Defaults to Table. Actually produces an HTML
table either way; with Table the output is a grid-like display. With
List the output is a two-column table with properties in the left column
and values in the right column.

.PARAMETER Properties
A comma-separated list of properties to include in the HTML fragment.
This can be * (which is the default) to include all properties of the
piped-in object(s). In addition to property names, you can also use a
hashtable similar to that used with Select-Object. For example:

 Get-Process | ConvertTo-EnhancedHTMLFragment -As Table `
               -Properties Name,ID,@{n='VM';
                                     e={$_.VM};
                                     css={if ($_.VM -gt 100) { 'red' }
                                          else { 'green' }}}


This will create table cell rows with the calculated CSS class names.
E.g., for a process with a VM greater than 100, you'd get:

  <TD class="red">475858</TD>
  
You can use this feature to specify a CSS class for each table cell
based upon the contents of that cell. Valid keys in the hashtable are:

  n, name, l, or label: The table column header
  e or expression: The table cell contents
  css or csslcass: The CSS class name to apply to the <TD> tag 
  
Another example:

  @{n='Free(MB)';
    e={$_.FreeSpace / 1MB -as [int]};
    css={ if ($_.FreeSpace -lt 100) { 'red' } else { 'blue' }}
    
This example creates a column titled "Free(MB)". It will contain
the input object's FreeSpace property, divided by 1MB and cast
as a whole number (integer). If the value is less than 100, the
table cell will be given the CSS class "red." If not, the table
cell will be given the CSS class "blue." The supplied cascading
style sheet must define ".red" and ".blue" for those to have any
effect.  

.PARAMETER PreContent
Raw HTML content to be placed before the wrapping <DIV> tag. 
For example:

    -PreContent "<h2>Section A</h2>"

.PARAMETER PostContent
Raw HTML content to be placed after the wrapping <DIV> tag.
For example:

    -PostContent "<hr />"

.PARAMETER MakeHiddenSection
Used in conjunction with -PreContent. Adding this switch, which
needs no value, turns your -PreContent into  clickable report
section header. The section will be hidden by default, and clicking
the header will toggle its visibility.

When using this parameter, consider adding a symbol to your -PreContent
that helps indicate this is an expandable section. For example:

    -PreContent '<h2>&diams; My Section</h2>'

If you use -MakeHiddenSection, you MUST provide -PreContent also, or
the hidden section will not have a section header and will not be
visible.

.PARAMETER MakeTableDynamic
When using "-As Table", makes the table dynamic. Will be ignored
if you use "-As List". Dynamic tables are sortable, searchable, and
are paginated.

You should not use even/odd styling with tables that are made
dynamic. Dynamic tables automatically have their own even/odd
styling. You can apply CSS classes named ".odd" and ".even" in 
your CSS to style the even/odd in a dynamic table.

.EXAMPLE
 $fragment = Get-WmiObject -Class Win32_LogicalDisk |
             Select-Object -Property PSComputerName,DeviceID,FreeSpace,Size |
             ConvertTo-HTMLFragment -EvenRowClass 'even' `
                                    -OddRowClass 'odd' `
                                    -PreContent '<h2>Disk Report</h2>' `
                                    -MakeHiddenSection `
                                    -MakeTableDynamic

 You will usually save fragments to a variable, so that multiple fragments
 (each in its own variable) can be passed to ConvertTo-EnhancedHTML.
.NOTES
Consider adding the following to your CSS when using dynamic tables:

    .paginate_enabled_next, .paginate_enabled_previous {
        cursor:pointer; 
        border:1px solid #222222; 
        background-color:#dddddd; 
        padding:2px; 
        margin:4px;
        border-radius:2px;
    }
    .paginate_disabled_previous, .paginate_disabled_next {
        color:#666666; 
        cursor:pointer;
        background-color:#dddddd; 
        padding:2px; 
        margin:4px;
        border-radius:2px;
    }
    .dataTables_info { margin-bottom:4px; }

This applies appropriate coloring to the next/previous buttons,
and applies a small amount of space after the dynamic table.

If you choose to make sections hidden (meaning they can be shown
and hidden by clicking on the section header), consider adding
the following to your CSS:

    .sectionheader { cursor:pointer; }
    .sectionheader:hover { color:red; }

This will apply a hover-over color, and change the cursor icon,
to help visually indicate that the section can be toggled.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [object[]]$InputObject,


        [string]$EvenRowCssClass,
        [string]$OddRowCssClass,
        [string]$TableCssID,
        [string]$DivCssID,
        [string]$DivCssClass,
        [string]$TableCssClass,


        [ValidateSet('List','Table')]
        [string]$As = 'Table',


        [object[]]$Properties = '*',


        [string]$PreContent,


        [switch]$MakeHiddenSection,


        [switch]$MakeTableDynamic,


        [string]$PostContent
    )
    BEGIN {
        <#
            Accumulate output in a variable so that we don't
            produce an array of strings to the pipeline, but
            instead produce a single string.
        #>
        $out = ''


        <#
            Add the section header (pre-content). If asked to
            make this section of the report hidden, set the
            appropriate code on the section header to toggle
            the underlying table. Note that we generate a GUID
            to use as an additional ID on the <div>, so that
            we can uniquely refer to it without relying on the
            user supplying us with a unique ID.
        #>
        Write-Verbose "Precontent"
        if ($PSBoundParameters.ContainsKey('PreContent')) {
            if ($PSBoundParameters.ContainsKey('MakeHiddenSection')) {
               [string]$tempid = [System.Guid]::NewGuid()
               $out += "<span class=`"sectionheader`" onclick=`"`$('#$tempid').toggle(500);`">$PreContent</span>`n"
            } else {
                $out += $PreContent
                $tempid = ''
            }
        }


        <#
            The table will be wrapped in a <div> tag for styling
            purposes. Note that THIS, not the table per se, is what
            we hide for -MakeHiddenSection. So we will hide the section
            if asked to do so.
        #>
        Write-Verbose "DIV"
        if ($PSBoundParameters.ContainsKey('DivCSSClass')) {
            $temp = " class=`"$DivCSSClass`""
        } else {
            $temp = ""
        }
        if ($PSBoundParameters.ContainsKey('MakeHiddenSection')) {
            $temp += " id=`"$tempid`" style=`"display:none;`""
        } else {
            $tempid = ''
        }
        if ($PSBoundParameters.ContainsKey('DivCSSID')) {
            $temp += " id=`"$DivCSSID`""
        }
        $out += "<div $temp>"


        <#
            Create the table header. If asked to make the table dynamic,
            we add the CSS style that ConvertTo-EnhancedHTML will look for
            to dynamic-ize tables.
        #>
        Write-Verbose "TABLE"
        $_TableCssClass = ''
        if ($PSBoundParameters.ContainsKey('MakeTableDynamic') -and $As -eq 'Table') {
            $_TableCssClass += 'enhancedhtml-dynamic-table '
        }
        if ($PSBoundParameters.ContainsKey('TableCssClass')) {
            $_TableCssClass += $TableCssClass
        }
        if ($_TableCssClass -ne '') {
            $css = "class=`"$_TableCSSClass`""
        } else {
            $css = ""
        }
        if ($PSBoundParameters.ContainsKey('TableCSSID')) {
            $css += "id=`"$TableCSSID`""
        } else {
            if ($tempid -ne '') {
                $css += "id=`"$tempid`""
            }
        }
        $out += "<table $css>"


        <#
            We're now setting up to run through our input objects
            and create the table rows
        #>
        $fragment = ''
        $wrote_first_line = $false
        $even_row = $false


        if ($properties -eq '*') {
            $all_properties = $true
        } else {
            $all_properties = $false
        }


    }
    PROCESS {


        foreach ($object in $inputobject) {
            Write-Verbose "Processing object"
            $datarow = ''
            $headerrow = ''


            <#
                Apply even/odd row class. Note that this will mess up the output
                if the table is made dynamic. That's noted in the help.
            #>
            if ($PSBoundParameters.ContainsKey('EvenRowCSSClass') -and $PSBoundParameters.ContainsKey('OddRowCssClass')) {
                if ($even_row) {
                    $row_css = $OddRowCSSClass
                    $even_row = $false
                    Write-Verbose "Even row"
                } else {
                    $row_css = $EvenRowCSSClass
                    $even_row = $true
                    Write-Verbose "Odd row"
                }
            } else {
                $row_css = ''
                Write-Verbose "No row CSS class"
            }


            <#
                If asked to include all object properties, get them.
            #>
            if ($all_properties) {
                $properties = $object | Get-Member -MemberType Properties | Select -ExpandProperty Name
            }


            <#
                We either have a list of all properties, or a hashtable of
                properties to play with. Process the list.
            #>
            foreach ($prop in $properties) {
                Write-Verbose "Processing property"
                $name = $null
                $value = $null
                $cell_css = ''


                <#
                    $prop is a simple string if we are doing "all properties,"
                    otherwise it is a hashtable. If it's a string, then we
                    can easily get the name (it's the string) and the value.
                #>
                if ($prop -is [string]) {
                    Write-Verbose "Property $prop"
                    $name = $Prop
                    $value = $object.($prop)
                } elseif ($prop -is [hashtable]) {
                    Write-Verbose "Property hashtable"
                    <#
                        For key "css" or "cssclass," execute the supplied script block.
                        It's expected to output a class name; we embed that in the "class"
                        attribute later.
                    #>
                    if ($prop.ContainsKey('cssclass')) { $cell_css = $Object | ForEach $prop['cssclass'] }
                    if ($prop.ContainsKey('css')) { $cell_css = $Object | ForEach $prop['css'] }


                    <#
                        Get the current property name.
                    #>
                    if ($prop.ContainsKey('n')) { $name = $prop['n'] }
                    if ($prop.ContainsKey('name')) { $name = $prop['name'] }
                    if ($prop.ContainsKey('label')) { $name = $prop['label'] }
                    if ($prop.ContainsKey('l')) { $name = $prop['l'] }


                    <#
                        Execute the "expression" or "e" key to get the value of the property.
                    #>
                    if ($prop.ContainsKey('e')) { $value = $Object | ForEach $prop['e'] }
                    if ($prop.ContainsKey('expression')) { $value = $tObject | ForEach $prop['expression'] }


                    <#
                        Make sure we have a name and a value at this point.
                    #>
                    if ($name -eq $null -or $value -eq $null) {
                        Write-Error "Hashtable missing Name and/or Expression key"
                    }
                } else {
                    <#
                        We got a property list that wasn't strings and
                        wasn't hashtables. Bad input.
                    #>
                    Write-Warning "Unhandled property $prop"
                }


                <#
                    When constructing a table, we have to remember the
                    property names so that we can build the table header.
                    In a list, it's easier - we output the property name
                    and the value at the same time, since they both live
                    on the same row of the output.
                #>
                if ($As -eq 'table') {
                    Write-Verbose "Adding $name to header and $value to row"
                    $headerrow += "<th>$name</th>"
                    $datarow += "<td$(if ($cell_css -ne '') { ' class="'+$cell_css+'"' })>$value</td>"
                } else {
                    $wrote_first_line = $true
                    $headerrow = ""
                    $datarow = "<td$(if ($cell_css -ne '') { ' class="'+$cell_css+'"' })>$name :</td><td$(if ($cell_css -ne '') { ' class="'+$cell_css+'"' })>$value</td>"
                    $out += "<tr$(if ($row_css -ne '') { ' class="'+$row_css+'"' })>$datarow</tr>"
                }
            }


            <#
                Write the table header, if we're doing a table.
            #>
            if (-not $wrote_first_line -and $as -eq 'Table') {
                Write-Verbose "Writing header row"
                $out += "<tr>$headerrow</tr><tbody>"
                $wrote_first_line = $true
            }


            <#
                In table mode, write the data row.
            #>
            if ($as -eq 'table') {
                Write-Verbose "Writing data row"
                $out += "<tr$(if ($row_css -ne '') { ' class="'+$row_css+'"' })>$datarow</tr>"
            }
        }
    }
    END {
        <#
            Finally, post-content code, the end of the table,
            the end of the <div>, and write the final string.
        #>
        Write-Verbose "PostContent"
        if ($PSBoundParameters.ContainsKey('PostContent')) {
            $out += "`n$PostContent"
        }
        Write-Verbose "Done"
        $out += "</tbody></table></div>"
        Write-Output $out
    }
}


#region Initialize
# To get the publishsettings file initially, use the cmdlet: Get-AzurePublishSettingsFile
if (!(Test-Path $PublishSettingsFile)) { log 'Error: missing Azure Publish Settings file', $PublishSettingsFile Magenta,Yellow $LogFile; break }
Import-AzurePublishSettingsFile -PublishSettingsFile $PublishSettingsFile
Select-AzureSubscription -SubscriptionName $SubscriptionName -Current
Select-AzureStorSimpleResource -ResourceName $StorSimpleManagerName -RegistrationKey $RegistrationKey
$Style = @"
<style>
body {
    color:#333333;
    font-family:Calibri,Tahoma;
    font-size: 10pt;
}
h1 {
    text-align:center;
}
h2 {
    border-top:1px solid #666666;
}

th {
    font-weight:bold;
    color:#eeeeee;
    background-color:#333333;
    cursor:pointer;
}
.odd  { background-color:#ffffff; }
.even { background-color:#dddddd; }
.paginate_enabled_next, .paginate_enabled_previous {
    cursor:pointer; 
    border:1px solid #222222; 
    background-color:#dddddd; 
    padding:2px; 
    margin:4px;
    border-radius:2px;
}
.paginate_disabled_previous, .paginate_disabled_next {
    color:#666666; 
    cursor:pointer;
    background-color:#dddddd; 
    padding:2px; 
    margin:4px;
    border-radius:2px;
}
.dataTables_info { margin-bottom:4px; }
.sectionheader { cursor:pointer; }
.sectionheader:hover { color:red; }
.grid { width:100% }
.red {
    color:red;
    font-weight:bold;
} 
</style>
"@
#endregion


#region Get incomplete jobs
$Tables = @()
$FailureReport = @()
$Jobs = Get-AzureStorSimpleJob -DeviceName $TargetDeviceName -Type Backup -From (Get-Date).AddDays(-$Duration) | where { $_.Status -ne 'Completed' }
if ($Jobs) {
    $i = 0
    $Jobs | % {
        $i++
        Write-Progress -activity "Processing volume $($Volumes.Name)" -status "$i of $($Jobs.Count) - $("{0:N0}" -f (($i/$Jobs.Count)*100))% " -PercentComplete (($i/$Jobs.Count)*100)
        $Volumes = Get-AzureStorSimpleDeviceBackupPolicy -BackupPolicyName $_.Entity.Name -DeviceName $TargetDeviceName
        $BackupDuration = New-TimeSpan -Start $_.TimeStats.StartTimestamp -End $_.TimeStats.EndTimestamp
        $Props = [ordered]@{
            'Volume(s)'              = $Volumes.Name -join ', '
            BackupStatus             = $_.Status
            BackupType               = $_.BackupType 
            'TotalData(GB)'          = "{0:N0}" -f ($_.DataStats.TotalData/1GB)
            'CloudData(GB)'          = "{0:N2}" -f ($_.DataStats.CloudData/1GB)
            BackupStartTime          = $_.TimeStats.StartTimestamp
            'BackupThroughput(Mbps)' = "{0:N2}" -f ($_.DataStats.Throughput/1MB*8)
            ErrorInfo                = $_.ErrorDetails
            ErrorDetails             = $_.JobDetails.Error
        }
        $FailureReport += New-Object -TypeName PSObject -Property $Props 
    }
    log "Incomplete backup jobs ($($FailureReport.Count)) in the past $Duration days:"  -LogFile $LogFile -Color Magenta
    log ($FailureReport | FT -a | Out-String) -LogFile $LogFile -Color Magenta

    $Params = @{
        'As'              = 'Table'
        'PreContent'      = "<h2>Incomplete backup jobs in the past $Duration days:</h2>"
        'EvenRowCssClass' = 'even'
        'OddRowCssClass'  = 'odd'
        'MakeTableDynamic'= $true
        'TableCssClass'   = 'grid'
        'Properties'      = $Props.Keys 
    }
    $Table = $FailureReport  | ConvertTo-EnhancedHTMLFragment @params
    $Tables += $Table

} else {
    log "No incomplete backup jobs found for volumes of the device $TargetDeviceName in the past $Duration days" -LogFile $LogFile -Color Cyan
}
#endregion


#region Get successful jobs
$SuccessReport = @()
$Jobs = Get-AzureStorSimpleJob -DeviceName $TargetDeviceName -Type Backup -From (Get-Date).AddDays(-$Duration) | where { $_.Status -eq 'Completed' }
if ($Jobs) {
    $i = 0
    $Jobs | % {
        $i++
        Write-Progress -activity "Processing volume $($Volumes.Name)" -status "$i of $($Jobs.Count) - $("{0:N0}" -f (($i/$Jobs.Count)*100))% " -PercentComplete (($i/$Jobs.Count)*100)
        $Volumes = Get-AzureStorSimpleDeviceBackupPolicy -BackupPolicyName $_.Entity.Name -DeviceName $TargetDeviceName
        $BackupDuration = New-TimeSpan -Start $_.TimeStats.StartTimestamp -End $_.TimeStats.EndTimestamp
        $Props = [ordered]@{
            'Volume(s)'                = $Volumes.Name -join ', '
            BackupStatus               = $_.Status
            BackupType                 = $_.BackupType 
            'TotalData(GB)'            = "{0:N0}" -f ($_.DataStats.TotalData/1GB)
            'CloudData(GB)'            = "{0:N2}" -f ($_.DataStats.CloudData/1GB)
            BackupStartTime            = $_.TimeStats.StartTimestamp
            BackupEndTime              = $_.TimeStats.EndTimestamp
            'BackupDuration(hh:mm:ss)' = "$($BackupDuration.Hours):$($BackupDuration.Minutes):$($BackupDuration.Seconds)"
            'BackupThroughput(Mbps)'   = "{0:N2}" -f ($_.DataStats.Throughput/1MB*8)
        }
        $SuccessReport += New-Object -TypeName PSObject -Property $Props 
    }
    log "Successful backup jobs ($($SuccessReport.Count)) in the past $Duration days:"  -LogFile $LogFile -Color Green
    log ($SuccessReport | FT -a | Out-String) -LogFile $LogFile -Color Green

    $Params = @{
        As               = 'Table'
        PreContent       = "<h2>Successful backup jobs in the past $Duration days:</h2>"
        EvenRowCssClass  = 'even'
        OddRowCssClass   = 'odd'
        MakeTableDynamic = $true
        TableCssClass    = 'grid'
        Properties       = $Props.Keys 
    }
    $Table = $SuccessReport | ConvertTo-EnhancedHTMLFragment @params
    $Tables += $Table

} else {
    log "No successful backup jobs found for volumes of the device $TargetDeviceName in the past $Duration days" -LogFile $LogFile -Color Cyan
}
#endregion


#region Compile and email report
$PreContent = "<h1>StorSimple Backup Report for the device $TargetDeviceName from $((Get-Date).AddDays(-$Duration)) to $(Get-Date)</h1>"
if (! $Tables) { $Tables = "No backups found for StorSimple device $TargetDeviceName from $((Get-Date).AddDays(-$Duration)) to $(Get-Date)" }
$Tables += "<hr> Report run time: $(Get-Date -format 'dd/MM/yyyy hh:mm:ss tt') - report run at "
$Tables += "$((GWMI Win32_ComputerSystem).Name).$((GWMI Win32_ComputerSystem).Domain) ($(([System.TimeZone]::CurrentTimeZone).StandardName))"
$Params = @{
    CssStyleSheet      = $Style
    Title              = "StorSimple Backup Report for the device $TargetDeviceName <br>from $((Get-Date).AddDays(-$Duration)) to $(Get-Date)"
    PreContent         = $PreContent
    HTMLFragments      = $Tables
    jQueryDataTableUri = 'http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.3/jquery.dataTables.min.js'
    jQueryUri          = 'http://ajax.aspnetcdn.com/ajax/jQuery/jquery-1.8.2.min.js'
} 
ConvertTo-EnhancedHTML @params | Out-File -FilePath $HTMLFile


$Error.Clear()
try { 
    $Params = @{ 
        From        = $EmailSender
        To          = $EmailRecipients 
        Body        = (Get-Content -Path $HTMLFile | Out-String) 
        SmtpServer  = $SMTPServer 
        Subject     = "StorSimple Backup Report generated on $(Get-Date -format 'dd/MM/yyyy HH:mm')" 
        Priority    = 'High' 
        ErrorAction = 'Stop' 
        BodyAsHtml  = $true
    }
    Send-MailMessage @Params
    log "Successfully emailed StorSimple backup report" -LogFile $LogFile -Color Green
} catch {
    log "Failed to send email report" -LogFile $LogFile -Color Magenta
    log "Error details: $Error"  -LogFile $LogFile -Color Magenta
}
#endregion