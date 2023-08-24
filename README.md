## Setting up Neovim

Run the following commands to install development version of Neovim:

```sh
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo apt update
sudo apt install neovim
```

After the installation is done, make sure you have installed pre-requisites for NvChad:

- Nerd Font (on Host) - ex. JetbrainsMono Nerd Font
- GCC

Then run:

```sh
git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
```

After starting neovim for the first time after the above installation, you will be prompted for creating an example custom config, select No by typing `n`.

Clone this repository as the custom folder

```
git clone https://github.com/NarendraPatwardhan/editorconfig ~/.config/nvim/lua/custom
```

