##################################################################
# remember, this might be built on Linux which is case sensitive #
# and the slashes are different                                  #
##################################################################

Describe 'Module-level tests' {
    BeforeAll {
        $projectRoot = $env:projectRoot
        $config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
        # $moduleRoot = Split-Path (Get-ChildItem $projectRoot -Include "*.psd1" -Recurse)
        $moduleRoot = Join-Path $env:Build_StagingDirectory -ChildPath $config.name
        $moduleManifest = Join-Path $moduleRoot -ChildPath "$($config.name).psd1"
    }

    Context 'The module has an associated manifest' {
        It "Should verify that the module manifest, $moduleManifest, exists" {
            Test-Path $moduleManifest -PathType Leaf | Should -Be $true
        }
    }

    Context 'Passes all default PSScriptAnalyzer rules' {
        It "Should invoke PSScriptAnalyzer and expect no output" {
            Invoke-ScriptAnalyzer -Path $moduleManifest | Should -BeNullOrEmpty
        }
    }

    # can I import what I have on linux?
    Context "Module '$moduleName' can import cleanly" {
        It "should import the module without throwing an exception" {
            { Import-Module $moduleManifest -force } | Should -Not Throw
        }
    }
}

##################################################################
# remember, this might be built on Linux which is case sensitive #
# and the slashes are different                                  #
##################################################################
Describe "General project validation:" {
    BeforeAll {
        $projectRoot = $env:projectRoot
        $config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
        # $moduleRoot = Split-Path (Get-ChildItem $projectRoot -Include "*.psd1" -Recurse)
        $moduleRoot = Join-Path $env:Build_StagingDirectory -ChildPath $config.name
        $scripts = Get-ChildItem (Join-Path $moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File
    }

    Context "Do we have good path to module and child scripts?" {
        It "There should be some path in '$moduleRoot'." {
            Test-Path $moduleRoot | Should -Be $true
        }
        It "There should be some scripts in '$scripts'." {
            $scripts.Count | Should -BeGreaterThan 0
        }
    }

    Context "Individual public scripts validation" {
        # TestCases are splatted to the script so we need hashtables
        $testCase = $scripts | Foreach-Object { @{ file = $_ } }

        It "Script $($testCase.Count) should be greater than 0" {
            $testCase.Count | Should -BeGreaterThan 0
        }

        foreach ($test in $testCase) {
            It "Script $($test.file.Name) should exist" {
                $test.file | Should -Exist
            }

            It "Script $($test.file.Name) should be valid powershell" -TestCases $test {
                param($file)

                Test-Path $file.FullName -PathType Leaf | Should -Be $true

                $contents = Get-Content -Path $file.FullName -ErrorAction Stop
                $errors = $null
                $tokens = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
                $tokens.Count | Should -BeGreaterThan 0
                $errors.Count | Should -Be 0
            }
        }
    }
}