    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string] $ProjectName,
        [ValidateSet("Api")]
        [string]$Type = "Api",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [ValidateSet("net5.0", "net6.0", "net7.0")]
        [string]$TargetFramework = "net6.0"                
    )
    
    begin {
        $Destination = Join-Path (Get-Location) $ProjectName
        New-Item $Destination -Force -ItemType Directory

        #create nuget, readme, dotnet gitignore get from github
        function New-Readme() {
            $content = "# $ProjectName"
            $content | Out-File -FilePath (Join-Path $Destination "README.md")            
        }
    }
    
    process {
        
        $executionFolder = Get-Location
        $src = Join-Path $Destination "src"
        $test = Join-Path $Destination "test"
        New-Item $src -ItemType Directory -Force
        New-Item $test -ItemType Directory -Force        

        New-Readme        
            
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Tappau/dotnet-defaults/main/.editorconfig"`
         -OutFile (Join-Path $Destination ".editorconfig") -UseDefaultCredentials
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Tappau/dotnet-defaults/main/.gitattributes"`
         -OutFile (Join-Path $Destination ".gitattributes") -UseDefaultCredentials
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore" -OutFile (Join-Path $Destination ".gitignore")

        ## now create the new type
        switch ($type) {
            "api" { 
                set-location $destination

                #create the sln
                dotnet new sln -n $projectname

                $projname = "$($projectname)"
                $projpath = join-path $src (join-path $projname "$projname.csproj")
                dotnet new webapi -n $projname --framework $TargetFramework -o (join-path $src $projname)
                dotnet sln add $projpath
				#add/update main packages
                dotnet add $projpath package "swashbuckle.aspnetcore"
                dotnet add $projpath package "swashbuckle.aspnetcore.filters"                

                $testname = "$($projname).Tests"
                $testpath = join-path $test (join-path $testname "$testname.csproj")
                dotnet new xunit -o (join-path $test $testname)
                dotnet sln add $testpath

                dotnet add $testpath reference $projpath

                ##now add/update the key test versions                
                dotnet add $testpath package "microsoft.net.test.sdk"
                dotnet add $testpath package "coverlet.collector"
                dotnet add $testpath package "fluentassertions"
                dotnet add $testpath package "moq"
                
                #Rename the Usings.cs to GlobalUsings.cs if not already from the template
                Get-ChildItem -Path (Split-Path -Parent $testpath) -Filter 'Usings.cs' -Recurse | ForEach-Object {
                    Rename-Item $_.FullName -NewName "GlobalUsings.cs"
                }
             }
            default {}
        }
    }    
    end {
        Set-Location $executionFolder
    }
