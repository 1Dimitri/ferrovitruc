# Split-TR3andGlossary
#
# returns a collection of PSCustomObject whose fields are:
# a pair of hashtable
# TR3
#  TR3:  1,2,3 letter abbreviation of the train station according to former SNCF's TR3 referential
#  Station: name of the train station in French, some diacritics may be missing due to source mixing upper and lower letters
# 
# lex
#  a term, meaning hashtable
function Split-TR3andGlossary {
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
    $TR3List = [ordered]@{ }
    $LexiconList = [ordered]@{ }
    $csv | ForEach-Object { 
        # Définition and Abréviation titles are not properly handled by $_."Définition" syntax due to editor codepages etc
        # workaround get the properties by index, skip 1st field, get 2 and 3
        $PropsNValues = $_.PSObject.Properties | Select-Object -Skip 1 -First 2
        $term = $PropsNValues[0].Value

        if (($term.Length -le 3) -and ($PropsNValues[1].Value -match "(.+) \(gare\)") -and (!$term.StartsWith('VISITE'))) {
            # TO DO: CHANGE ALGORITHM..
            #VTE corresponds both to VITRE (GARE) and VISITE TECHNIQUE D'ECHANGE (GARE)
            $station = $matches[1]
            
            Write-Verbose "Found train station: $station"
            $TR3List.Add($term, $TextInfo.ToTitleCase($station.ToLower()))
            # yet another workaround: TitleCase only works with starting lower case string;           
        }
        else {
            # not a train station
            
            $meaning = $PropsNValues[1].Value -replace '_x000D_', '. '
            Write-Verbose "Found glossary entry: $term"
            if ($LexiconList.Contains($term)) {
                $add_meaning = $LexiconList[$term]
                $LexiconList[$term]= $meaning + $add_meaning
            }
            else {
                $LexiconList.Add($term, $meaning)
            }
        
    
        }

    }

    Remove-Item $tempfilename -Force
    ($TR3List, $LexiconList)
}


# Create markdown .md files tr3.Md and gare.md from previous function
function New-TR3GlossaryMdFiles {

    ($tr3, $lex) = Split-TR3andGlossary

    $mdFiles = @(
        @{title = 'Lexique SNCF'; fname = 'Lexique-SNCF.md'; col1 = 'Abréviation'; col2 = 'signification';
            linesb = { @("# $($_.key)", "$($_.value)") }; list = $lex
        },
        @{title = 'TR3 -> Gare SNCF'; fname = 'TR3.md'; col1 = 'Abréviation'; col2 = 'Nom de la gare';
            linesb = { "| $($_.key) | $($_.value) |" }; list = $tr3
        },
        @{title = 'Gare -> TR3'; fname = 'gare.md'; col1 = 'Nom de la gare'; col2 = 'Abréviation';
            linesb = { "| $($_.value) | $($_.key) |" }; list = $tr3
        }
    )
        
      
    $mdFiles | ForEach-Object {
        $fn = $_.fname
        "" | Set-Content $fn -Force
        "# $($_.title)" | Add-Content $fn -Force
        "" | Set-Content $fn -Force

        "| $($_.col1) |$($_.col2) |" | Add-Content $fn -Force
        "| --- | ---- |" | Add-Content $fn -Force

        # todo: put contents
        $sb = $_.linesb
        $_.list.GetEnumerator() | ForEach-Object {
            &$sb | Add-Content $fn -Force
        }
        "" | Add-Content $fn -Force

    }
 
  


}