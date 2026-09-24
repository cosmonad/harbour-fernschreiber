/*
    Copyright (C) 2020 Sebastian J. Wolf and other contributors

    This file is part of Fernschreiber.

    Fernschreiber is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Fernschreiber is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Fernschreiber. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.6
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Nemo.Thumbnailer 1.0
import WerkWolf.Fernschreiber 1.0

// A still of the animation, played only while its menu is open: every playing
// video is a media pipeline of its own, too heavy for a whole grid
GridItem {
    id: animationPickerItem

    property var animation

    signal sendRequested()

    // Not from within the menu: it is gone once closed, and so would be
    // everything its functions look up by then, tdLibWrapper included
    function removeFromSavedAnimations() {
        var fileId = animation.animation.id;
        remorseAction(qsTr("Removing GIF"), function() {
            tdLibWrapper.removeSavedAnimation(fileId);
        });
    }

    menu: Component {
        ContextMenu {
            id: animationMenu
            // Asked when the menu opens, it is created anew every time
            readonly property bool saved: stickerManager.isAnimationSaved(animationPickerItem.animation.animation.id)
            MenuItem {
                text: qsTr("Send")
                onClicked: animationPickerItem.sendRequested()
            }
            MenuItem {
                text: animationMenu.saved ? qsTr("Remove from GIFs") : qsTr("Add to GIFs")
                onClicked: {
                    if (animationMenu.saved) {
                        animationPickerItem.removeFromSavedAnimations();
                    } else {
                        tdLibWrapper.addSavedAnimation(animationPickerItem.animation.animation.id);
                    }
                }
            }
        }
    }

    TDLibThumbnail {
        id: still
        anchors.fill: parent
        thumbnail: animationPickerItem.animation.thumbnail
        minithumbnail: animationPickerItem.animation.minithumbnail
        fillMode: Image.PreserveAspectCrop
        highlighted: animationPickerItem.highlighted
        visible: !(videoLoader.item && videoLoader.item.started)
    }

    // Some animations come without a thumbnail, or with one that can't be
    // read. Their first frame is taken instead, from the animation itself.
    Timer {
        id: stillTimeout
        interval: 1500
        running: true
    }

    Loader {
        id: firstFrameLoader
        anchors.fill: parent
        // hasVisibleThumbnail is true while none is showing, despite its name
        active: !stillTimeout.running && still.hasVisibleThumbnail
        sourceComponent: Component {
            Item {
                TDLibFile {
                    id: animationFile
                    tdlib: tdLibWrapper
                    fileInformation: animationPickerItem.animation.animation
                    autoLoad: true
                }
                Thumbnail {
                    anchors.fill: parent
                    source: animationFile.isDownloadingCompleted ? animationFile.path : ""
                    mimeType: animationPickerItem.animation.mime_type || "video/mp4"
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Thumbnail.PreserveAspectCrop
                    visible: status === Thumbnail.Ready
                }
            }
        }
    }

    Loader {
        id: videoLoader
        anchors.fill: parent
        active: animationPickerItem.menuOpen
        sourceComponent: Component {
            Item {
                property alias started: animationVideo.started
                // Filled while cropped, it would reach over the neighbouring cells
                clip: true

                TDLibFile {
                    id: file
                    tdlib: tdLibWrapper
                    fileInformation: animationPickerItem.animation.animation
                    autoLoad: true
                }

                Video {
                    id: animationVideo
                    anchors.fill: parent
                    source: file.isDownloadingCompleted ? file.path : ""
                    autoPlay: true
                    muted: true
                    fillMode: VideoOutput.PreserveAspectCrop
                    // Stays shown while restarting, instead of the thumbnail flashing up
                    property bool started
                    onPlaying: started = true
                    // Video of Qt 5.6 has no loops property yet, and ignores
                    // play() while still reporting the end of the media
                    onStatusChanged: {
                        if (status === MediaPlayer.EndOfMedia) {
                            loopTimer.start();
                        }
                    }
                    Timer {
                        id: loopTimer
                        interval: 0
                        onTriggered: animationVideo.play()
                    }
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Medium
                    running: !file.isDownloadingCompleted
                }
            }
        }
    }
}
