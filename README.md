What did I try:

snippet from `Makefile`:
```shell
echo "file://`realpath ./artifact`" > ./url
nix-hash --type sha256 --base32 ./artifact ./sha256
nix-prefetch-url --type sha256 --name artifact \
		`printf \`cat ./url\``
		`printf \`cat ./sha256\``
nice nix-build --pure -Q
```

snippet from `default.nix`
```nix
{ stdenv }:

with stdenv;

mkDerivation {
  name = "ma";
  src = with builtins; fetchTarball {
    url = replaceStrings ["\n"] [""] (
      readFile ./url
    );
    sha256 = replaceStrings ["\n"] [""] (
      readFile ./sha256
    );
  };
  installPhase = ''
    mkdir -p $out
    cp -a ./{.[^.]*,*} $out/
  '';
}
```

or simply:
```nix
{ stdenv, requireFile }:

with stdenv;

let
  src = with builtins; requireFile {
    url = replaceStrings ["\n"] [""] (
      readFile ./url
    );
    sha256 = replaceStrings ["\n"] [""] (
      readFile ./sha256
    );
    hashMode = "recursive";
  };
in

artifact = runCommand "artifact" {} ''
  mkdir -p $out
  cp -a ${src}/{.[^.]*,*} $out/
'';
```
