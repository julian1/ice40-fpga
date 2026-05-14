

#
#        use nix master2 -
#            commit 4918b0531db7451bf3f10faff6ec02ff003be3e7 (origin/master, origin/HEAD, master)
#            Merge: 8e09bce0243a d23ca67c2f2d
#            Author: Peder Bergebakken Sundt <pbsds@hotmail.com>
#            Date:   Fri Apr 10 22:04:04 2026 +0000
#
#            me@flow:~/devel/ice40-fpga/projects/minimal$ yosys --version
#            Yosys 0.62 (git sha1 v0.62, g++ 15.2.0 -fPIC -O3) 
#
#            low:~/devel/ice40-fpga/projects/minimal$ nextpnr-ice40 --version
#            "nextpnr-ice40" -- Next Generation Place and Route (Version nextpnr-0.10)
#

nix-shell ./shell.nix  -I nixpkgs=/home/me/devel/nixpkgs.master2

