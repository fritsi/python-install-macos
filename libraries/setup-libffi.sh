##############################################################################################
### For Python installation we need libffi                                                 ###
### We don't want to use the one which comes with Xcode, because that's only an rc version ###
### Prior to Python 3.8 only libffi 3.3.x is compatible with Python                        ###
### Since the latest version is libffi 3.4.x, if we are compiling an older Python,         ###
### we need a workaround to install libffi 3.3.x                                           ###
### This script will be sourced by libraries/search-libraries.sh                           ###
##############################################################################################

# We are NOT compiling Python at the moment, so there's nothing to do
if [[ "$G_PYTHON_COMPILE" -ne 1 ]]; then
    return
fi

# We are compiling at least Python 3.8, so there's nothing to do
if [[ "$PY_VERSION_NUM" -ge 308 ]]; then
    # The latest libffi which comes from brew is fine for us
    # Let's prepend that to 'T_LIBRARIES_TO_LOOKUP' which is declared in libraries/search-libraries.sh
    T_LIBRARIES_TO_LOOKUP="libffi $T_LIBRARIES_TO_LOOKUP"

    # Nothing else to do
    return
fi

# We'll need to use libffi 3.3.x, let's prepend that to 'T_LIBRARIES_TO_LOOKUP'
T_LIBRARIES_TO_LOOKUP="libffi33 $T_LIBRARIES_TO_LOOKUP"

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Checking libffi33 ..."
sysout ""

if [[ "$(brew list -1 | grep -ciF "libffi33" || true)" -gt 0 ]]; then
    # libffi33 is already installed, so there's nothing else to do
    return
fi

# Let's install libffi 3.3.x
# formulas/libffi33.rb was downloaded from an older hash of https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/libffi.rb,
# and then changed a bit

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} libffi 3.3.x is not installed, installing it now"
sysout ""

sysout ">> brew install --formula --build-from-source \"$SCRIPTS_DIR/formulas/libffi33.rb\""
sysout ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to execute the above command" && sysout ""
fi

brew install --formula --build-from-source "$SCRIPTS_DIR/formulas/libffi33.rb" 2>&1

sysout ""
sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} libffi 3.3.x installation completed"
sysout ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi
