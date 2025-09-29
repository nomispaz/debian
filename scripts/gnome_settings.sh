#change formats to German
gsettings set org.gnome.system.locale region 'de_DE.UTF-8'
#activate tap-to-click
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
#activate dark mode
#Appearance --> Style
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
#Gnome-Tweaks --> Appearance --> Legacy Applications
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

# disable natural scrolling for touchpad
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false

#activate night light
#I want to use the automativ schedule --> off as standard
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled false
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from 22
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to 24
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 3700

#keybindings

# close windos
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>q']"

#toggle fullscreen
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"

#move window to workspace 1 to 4
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Shift><Super>exclam']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Shift><Super>quotedbl']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Shift><Super>section']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Shift><Super>dollar']"

#disable Super+1 to super+3 from standard settings
gsettings set org.gnome.shell.keybindings switch-to-application-1 '@as []'
gsettings set org.gnome.shell.keybindings switch-to-application-2 '@as []'
gsettings set org.gnome.shell.keybindings switch-to-application-3 '@as []'

#switch to workspace 1 to 4
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"

#custom shortcuts
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
#start terminal
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'alacritty'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>Return'

#start text editor
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'emacs'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'emacs'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>e'

#start steam client
# change Super+s
gsettings set org.gnome.shell.keybindings toggle-overview '@as []'
gsettings set org.gnome.shell.keybindings toggle-quick-settings '@as []'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'steam'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command 'steam'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>s'


#Mute Micro
gsettings set org.gnome.settings-daemon.plugins.media-keys mic-mute "['<Super>y']"
