# ==============================================================================
# THE LOOK OF AN INSTANCE
# ==============================================================================
# What Windows Terminal shows for an instance: icon, colour scheme, font, tab
# title - and the recipe behind a drawn icon.
class WslTheme {
    [string]$IconPath
    [string]$ColorScheme
    [string]$FontName
    [string]$TabTitle

    # The letters and colours the icon is drawn from, so one change keeps the
    # others. Empty when the icon is an image of the user's, which has none.
    [string]$IconText
    [string]$IconTop
    [string]$IconBottom
    [string]$IconTextColor

    WslTheme() {}

    WslTheme([string]$icon, [string]$scheme, [string]$font, [string]$title) {
        $this.IconPath    = $icon
        $this.ColorScheme = $scheme
        $this.FontName    = $font
        $this.TabTitle    = $title
    }
}
