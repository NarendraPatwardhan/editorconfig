## Setting up Neovim

Run the following commands to install development version of Neovim:

```sh
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo apt update
sudo apt install neovim
```

After the installation is done, make sure you have installed pre-requisites for
NvChad:

- Nerd Font (on Host) - ex. JetbrainsMono Nerd Font
- GCC

Then run:

```sh
git clone git@github.com:NarendraPatwardhan/editorconfig.git ~/.config/nvim --depth 1
```

The above steps are not needed if using any of the machinelearning.one images.
Use the flux nvim-setup hook instead.
