# Get-Lexicon
#
# returns a collection of PSCustomObject whose fields are:
#
#  term:  Vocabulary term in SNCF jargon
#  meaning: explanation

function Get-Lexicon {
    $SncfGlossaryURLasCSV = 'https://data.sncf.com/explore/dataset/lexique-des-acronymes-sncf/download/?format=csv&timezone=Europe/Berlin&use_labels_for_header=true'
    $tempfilename = [System.IO.Path]::GetTempFileName()

    # Workaround to avoid " The underlying connection was closed: An unexpected error occurred on a send" error message due to TLS/SSL settings
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

    Write-Verbose "Retrieving $SncfGlossaryURLasCSV into $tempfilename"
    Invoke-WebRequest -UseBasicParsing -Uri $SncfGlossaryURLasCSV -OutFile $tempfilename   

    # French culture settings for CSV includes semi-colon and UTF8 for diacritics       
    $csv = Import-CSV -Path $tempfilename -Encoding UTF8 -Delimiter ';'
    
    $TextInfo = (Get-Culture).TextInfo
    $csv | ForEach-Object { 
        # Définition and Abréviation titles are not properly handled by $_."Définition" syntax due to editor codepages etc
        # workaround get the properties by index, skip 1st field, get 2 and 3
        $PropsNValues = $_.PSObject.Properties | Select-Object -Skip 1 -First 2
        if ($PropsNValues[1].Value -notmatch "(.+) \(gare\)") {
            $term = $PropsNValues[0].Value
            $meaning= $PropsNValues[1].Value -replace '_x000D_','. '
            Write-Verbose "Found: $term"
            [PSCustomObject]@{
                # yet another workaround: TitleCase only works with starting lower case string;
                term = $term
                meaning = $meaning               
            }
        }
    }

    Remove-Item $tempfilename -Force

}

# Create markdown .md file Lexicon.Md  from previous function
function New-LexiconMdFile {

    $lexicon = Get-Lexicon
    $lexiconfilename = 'Lexique-SNCF.md'
    
    "" | Set-Content $lexiconfilename -Force
    "# Lexique SNCF " | Add-Content $lexiconfilename -Force
    ""

    $lexicon| Sort-Object -Property term |   ForEach-Object {
       
        "# $($_.term)"| Add-Content $lexiconfilename -Force
        "$($_.meaning)"| Add-Content $lexiconfilename -Force
        ""| Add-Content $lexiconfilename -Force
    }
    "" | Add-Content $lexiconfilename -Force

}