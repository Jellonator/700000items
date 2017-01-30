mod_dest=~/.local/share/binding\ of\ isaac\ afterbirth+\ mods/700000items

echo $mod_dest

if [ -a "$mod_dest" ]
	then
	echo "Removing old"
	rm -rf "$mod_dest"
fi
echo "Putting in new"
cp -r 700000items "$mod_dest"
echo "Done!"
