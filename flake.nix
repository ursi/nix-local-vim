{
  outputs = { self, nixpkgs }: rec {
    mkFtdetect = ft: extension: {
      "${ft}.vim" = "au BufRead,BufNewFile *.${extension} set filetype=${ft}";
    };

    /* Turn a plugin object into a Vim plugin

      Example:
        plugin = {
          ftdetect =  mkFtdetect "spellcheck" "sc";

          ftplugin = {
            "text.vim" = ''
              set spell
            '';
          };
        };
    */
    mkPlugin = system: name: plugin:
      let
        inherit (nixpkgs.legacyPackages.${system}) runCommand vimUtils writeText;
        dirs = builtins.attrNames plugin;
        mkDirs = builtins.foldl' (acc: dir: acc + "mkdir $out/${dir};") "" dirs;

        files = builtins.foldl'
          (acc: dir:
            acc
              + builtins.foldl'
                  (acc': fileName:
                    let
                      file = writeText fileName plugin.${dir}.${fileName};
                    in
                      acc' + "cp ${file} $out/${dir}/${fileName};"
                  )
                  ""
                  (builtins.attrNames plugin.${dir})
          )
          ""
          dirs;
      in
        vimUtils.buildVimPlugin {
          inherit name;
          src = runCommand "" {} ("mkdir $out;" + mkDirs + files);
        };

    /* Add an `overlayConfig` attribute to neovim which will recursively update the configuration with additional configuration

      Example:
        neovim.overlayConfig
          (old: {
            customRC =
              (if old ? "customRC" then old.customRC + "\n"
               else ""
              )
                + "set relativenumber";

            packages.localPackage {
              start = [ myLocalPlugin ];
            };
          })
    */
    mkOverlayableNeovim = neovim: configure:
      (neovim.override { inherit configure; })
        .overrideAttrs
          (old:
            { passthru = old.passthru // {
                overlayConfig = overlay:
                  mkOverlayableNeovim
                    neovim
                    (nixpkgs.lib.recursiveUpdate
                      configure
                      (overlay configure)
                    );
            };
          });
  };
}
