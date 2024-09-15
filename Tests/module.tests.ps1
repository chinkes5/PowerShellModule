BeforeAll {
    $projectRoot = $env:projectRoot

    Write-Host "##[info] Reading config file..."
    $config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
    Write-Host "##[info] Project root: $projectRoot"

    $modulePath = Join-Path -Path $env:Build_StagingDirectory -ChildPath "$($config.name)"
    $manifestPath = Join-Path -Path $modulePath -ChildPath "$($config.name).psd1"
    Write-Host "##[info] Manifest Path: $manifestPath"

    $scripts = Get-ChildItem (Join-Path $modulePath -ChildPath 'Public') -Filter '*.ps1' -File
    Write-Host "##[info] scripts: $scripts"

    Write-Host "##[info] tests following..."
}

Describe 'Module-level tests' -Tag 'module' {
    Context 'The module has an associated manifest' {
        It "Should verify that the module manifest, $manifestPath, exists" {
            $manifestPath | Should -Exist
        }
    }

    Context 'Passes all default PSScriptAnalyzer rules' {
        It "Should invoke PSScriptAnalyzer and expect no output" {
            $saResults = Invoke-ScriptAnalyzer -Path $manifestPath
            $saResults.Count | Should -Be 0
        }
    }

    Context "Module '$($config.name)' can import cleanly" {
        It "should import the module without throwing an exception" {
            { Import-Module -Name $manifestPath -Force -Verbose } | Should -Not Throw
        }
    }
}

Describe "General project validation:" -Tag 'functions' {
    Context "Do we have good path to module and child scripts?" {
        It "There should be some path in '$modulePath'." {
            $modulePath | Should -Exist
        }
        It "There should be some scripts in '$scripts'." {
            $scripts.Count | Should -BeGreaterThan 0
        }
    }

    Context "Individual public scripts validation" {
        $testCases = @()
        foreach ($script in $scripts) {
            $testCases += [PSCustomObject]@{
                file = $script
            }
        }

        It "Script <file.Name> should exist" -TestCases $testCases {
            param($file)

            $file.FullName | Should -Exist
        }

        It "Script <file.Name> should be valid powershell" -TestCases $testCases {
            param($file)

            $contents = Get-Content -Path $file.FullName -ErrorAction Stop
            $errors = @()
            $tokens = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
            $tokens.Count | Should -BeGreaterThan 0
            $errors.Count | Should -Be 0
        }
    }
}
