Describe "Get-MenuSelection" {
    It "Returns the selected item when a valid selection is made" {
        # Arrange
        $menuItems = @("Option 1", "Option 2", "Option 3")
        $menuPrompt = "Select an option:"

        # Simulate user input (selecting the first option)
        $host.ui.rawui.readkey("NoEcho,IncludeKeyDown") | ForEach-Object { $_.virtualkeycode } | Where-Object { $_ -eq 49 } | Out-Null
        $host.ui.rawui.readkey("NoEcho,IncludeKeyDown") | ForEach-Object { $_.virtualkeycode } | Where-Object { $_ -eq 13 } | Out-Null

        # Act
        $result = Get-MenuSelection -MenuItems $menuItems -MenuPrompt $menuPrompt

        # Assert
        $result | Should -Be "Option 1"
    }

    It "Returns null when an invalid selection is made" {
        # Arrange
        $menuItems = @("Option 1", "Option 2", "Option 3")
        $menuPrompt = "Select an option:"

        # Act
        $host.ui.rawui.readkey("NoEcho,IncludeKeyDown") | ForEach-Object { $_.virtualkeycode } | Where-Object { $_ -eq 13 } | Out-Null
        $result = Get-MenuSelection -MenuItems $menuItems -MenuPrompt $menuPrompt

        # Assert
        $result | Should -BeNull
    }
}