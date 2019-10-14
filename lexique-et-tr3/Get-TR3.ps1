# Get-TR3
#
# returns a collection of PSCustomObject whose fiels are:
#
#  TR3:  1,2,3 letter abbreviation of the train station according to former SNCF's TR3 referential
#  Station: name of the train station in French, some diacritics may be missing due to source mixing upper and lower letters

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
    $TR3List = [System.collections.ArrayList]@()
    $LexiconList = [System.collections.ArrayList]@()
    $csv | ForEach-Object { 
        # Définition and Abréviation titles are not properly handled by $_."Définition" syntax due to editor codepages etc
        # workaround get the properties by index, skip 1st field, get 2 and 3
        $PropsNValues = $_.PSObject.Properties | Select-Object -Skip 1 -First 2
        $term = $PropsNValues[0].Value

        if (($term.Length -le 3) -and ($PropsNValues[1].Value -match "(.+) \(gare\)")) {
            $station= $matches[1]
            Write-Verbose "Found train station: $station"
            $TR3List.Add([PSCustomObject]@{
                # yet another workaround: TitleCase only works with starting lower case string;
                station = $TextInfo.ToTitleCase($station.ToLower())
                tr3 = $term
            }) | Out-Null
        } else { # not a train station
            
            $meaning= $PropsNValues[1].Value -replace '_x000D_','. '
            Write-Verbose "Found glossary entry: $term"
            $LexiconList.Add([PSCustomObject]@{
                # yet another workaround: TitleCase only works with starting lower case string;
                term = $term
                meaning = $meaning               
            }) | Out-Null
        }
    }

    Remove-Item $tempfilename -Force
    ($TR3List,$LexiconList)
}

# Create markdown .md files tr3.Md and gare.md from previous function
function New-TR3GlossaryMdFiles {

    ($tr3,$lex) = Split-TR3andGlossary

    $mdFiles = @(
        @{title = 'Lexique SNCF';fname='Lexique-SNCF.md';col1='Abréviation';col2='signification';
        linesb= { @("# $($_.term)","$($_.meaning)")};list=$lex},
        @{title = 'TR3 -> Gare SNCF';fname='TR3.md';col1='Abréviation';col2='Nom de la gare';
        linesb={"| $($_.tr3) | $($_.station) |"};list=$tr3},
        @{title = 'Gare -> TR3';fname='gare.md';col1='Nom de la gare';col2='Abréviation';
        linesb={"| $($_.station) | $($_.tr3) |"};list=$tr3}
    )
        
      
    $mdFiles | ForEach-Object {
        $fn = $_.fname
        "" | Set-Content $fn -Force
        "# $($_.title)" | Add-Content $fn -Force
        "" | Set-Content $fn -Force

        "| $($_.col1) |$($_.col2) |" | Add-Content $fn -Force
        "| --- | ---- |" | Add-Content $fn -Force

        # todo: put contents
        "" | Add-Content $fn -Force

    }
 
  


}