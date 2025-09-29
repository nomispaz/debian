# todo debian
# adjust sources.list and add non-free

# after installing dkms, run 
sudo dkms generate_mok
sudo mokutil --import /var/lib/dkms/mok.pub

sudo apt install sbsigntool

sudo mkdir -p /var/lib/shim-signed/mok/
sudo openssl req -nodes -new -x509 -newkey rsa:2048 -keyout /var/lib/shim-signed/mok/MOK.priv -outform DER -out /var/lib/shim-signed/mok/MOK.der -days 36500 -subj "/CN=nomispaz/"
sudo openssl x509 -inform der -in /var/lib/shim-signed/mok/MOK.der -out /var/lib/shim-signed/mok/MOK.pem
sudo mokutil --import /var/lib/shim-signed/mok/MOK.der
sudo sbsign --key /var/lib/shim-signed/mok/MOK.priv --cert /var/lib/shim-signed/mok/MOK.pem "/boot/vmlinuz-6.16-amd64" --output "/boot/vmlinuz-6.16-amd64.tmp"
sudo mv "/boot/vmlinuz-.tmp" "/boot/vmlinuz-$VERSION"
sudo mv "/boot/vmlinuz-6.16-amd64.tmp" "/boot/vmlinuz-6.16-amd64"
