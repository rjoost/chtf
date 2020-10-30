# Copyright (c) 2017 Alex Kulbii
# Copyright (c) 2018 Yleisradio Oy
# Copyright (c) 2020 Teemu Matilainen
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Set defaults

set -q CHTF_AUTO_INSTALL; or set -g CHTF_AUTO_INSTALL ask

if not set -q CHTF_TERRAFORM_DIR
    if test "$CHTF_AUTO_INSTALL_METHOD" = homebrew
        set -g CHTF_TERRAFORM_DIR (brew --caskroom)
    else if test -z "$CHTF_AUTO_INSTALL_METHOD"
        and string match -q 'yleisradio/terraforms' (brew tap 2>/dev/null)
        # https://github.com/Yleisradio/homebrew-terraforms in use
        set -g CHTF_TERRAFORM_DIR (brew --caskroom)
        set -g CHTF_AUTO_INSTALL_METHOD homebrew
    else
        set -g CHTF_TERRAFORM_DIR $HOME/.terraforms
    end
end

function chtf
    switch $argv[1]
        case -h --help
            echo 'usage: chtf [<version> | system]'
        case -V --version
            echo "chtf: $CHTF_VERSION"
        case ''
            _chtf_list
        case system
            _chtf_reset
        case '*'
            _chtf_use $argv[1]
    end
end

function _chtf_reset
    test -z "$CHTF_CURRENT"; and return 0

    set PATH (string match -v -- $CHTF_CURRENT $PATH)

    set -e CHTF_CURRENT
    set -e CHTF_CURRENT_TERRAFORM_VERSION
end

function _chtf_use -a tf_version
    set -l tf_path $CHTF_TERRAFORM_DIR/terraform-$tf_version

    if not test -d $tf_path
        _chtf_install $tf_version; or return 1
    end

    # Homebrew adds a subdir named by the package version, so we test that first
    if test -x $tf_path/$tf_version/terraform
        set tf_path $tf_path/$tf_version
    else if not test -x $tf_path/terraform
        echo "chtf: Failed to find terraform executable in $tf_path" >&2
        return 1
    end

    _chtf_reset

    set -gx CHTF_CURRENT $tf_path
    set -gx CHTF_CURRENT_TERRAFORM_VERSION $tf_version
    set PATH $CHTF_CURRENT $PATH
end

function _chtf_list
    for dir in $CHTF_TERRAFORM_DIR/terraform-*
        set -l tf_version (string replace -r '.*/terraform-' '' $dir)
        set -l prefix (_chtf_list_prefix $tf_version)
        printf '%s %s\n' $prefix $tf_version
    end
end

function _chtf_list_prefix -a tf_version
    if test "$tf_version" = "$CHTF_CURRENT_TERRAFORM_VERSION"
        printf ' *'
    else
        printf '  '
    end
end

function _chtf_install -a tf_version
    echo "chtf: Terraform version $tf_version not found" >&2

    switch "$CHTF_AUTO_INSTALL_METHOD"
        case homebrew
            _chtf_confirm $tf_version; or return 1
            echo "chtf: Installing Terraform version $tf_version"
            brew cask install "terraform-$tf_version"
        case '*'
            # Other auto installation methods not yet supported
            # TODO: https://github.com/robertpeteuil/terraform-installer
            return 1
    end
end

function _chtf_confirm
    switch "$CHTF_AUTO_INSTALL"
        case no false 0
            return 1
        case ask
            read -n 1 -P 'chtf: Do you want to install it? [yN] ' reply
            string match -qr '[Yy]' $reply; or return 1
    end
end

function _chtf_root_dir
    dirname (status --current-filename)
end

# Load and store the version number
set -g CHTF_VERSION (cat (_chtf_root_dir)/VERSION)
