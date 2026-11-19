# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-sailskaat

CONFIG += sailfishapp_qml

DISTFILES += qml/harbour-sailskaat.qml \
    qml/cover/CoverPage.qml \
    qml/cover/*.svg \
    qml/cover/harbour-sailskaat.png \
    qml/pages/GamePage.qml \
    qml/pages/AboutPage.qml \
    qml/components/DashedSlot.qml \
    qml/cards/PlayingCard.qml \
    qml/cards/TableCard.qml \
    qml/cards/cards.js \
    qml/js/skaat.js \
    tests/skaat-selftest.js \
    rpm/harbour-sailskaat.changes.in \
    rpm/harbour-sailskaat.changes.run.in \
    rpm/harbour-sailskaat.spec \
    translations/*.ts \
    harbour-sailskaat.desktop


# to disable building translations every time, comment out the
# following CONFIG line
#CONFIG += sailfishapp_i18n

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
