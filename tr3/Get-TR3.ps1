# Get-TR3
#
# returns a collection of PSCustomObject whose fiels are:
#
#  TR3:  1,2,3 letter abbreviation of the train station according to former SNCF's TR3 referential
#  Station: name of the train station in French, some diacritics may be missing due to source mixing upper and lower letters

function Get-TR3 {
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
        if ($PropsNValues[1].Value -match "(.+) \(gare\)") {
            $station= $matches[1]
            Write-Verbose "Found: $station"
            [PSCustomObject]@{
                # yet another workaround: TitleCase only works with starting lower case string;
                station = $TextInfo.ToTitleCase($station.ToLower())
                tr3 = $PropsNValues[0].Value
            }
        }
    }

    Remove-Item $tempfilename -Force

}