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

Item {
    id: animationPicker

    // Whether this is the page of the picker being looked at
    property bool current
    property string chatId

    // The saved GIFs are shown until something is searched for
    readonly property string searchQuery: searchField.text.trim()
    readonly property bool searching: searchQuery !== ""
    // Searching goes through the inline bot Telegram names for it, @gif as a rule
    readonly property string searchBotUserName: tdLibWrapper.getOptionString("animation_search_bot_username") || "gif"
    property string searchBotUserId
    property bool searchQueued
    property string searchExtra
    property string nextOffset
    property bool isLoading


    signal animationPicked(var animation)

    // Brought in line with the saved animations entry by entry: rebuilding it
    // would recreate every cell, and the grid couldn't show what changed
    function fillSavedAnimations() {
        var savedAnimations = stickerManager.getSavedAnimations();
        var savedIds = savedAnimations.map(function(savedAnimation) { return savedAnimation.animation.id; });
        var i;
        for (i = savedAnimationsModel.count - 1; i >= 0; i--) {
            if (savedIds.indexOf(savedAnimationsModel.get(i).animation.animation.id) < 0) {
                savedAnimationsModel.remove(i);
            }
        }
        for (i = 0; i < savedAnimations.length; i++) {
            var existingIndex = -1;
            for (var j = i; j < savedAnimationsModel.count; j++) {
                if (savedAnimationsModel.get(j).animation.animation.id === savedIds[i]) {
                    existingIndex = j;
                    break;
                }
            }
            if (existingIndex < 0) {
                savedAnimationsModel.insert(i, { "animation": savedAnimations[i] });
            } else if (existingIndex !== i) {
                savedAnimationsModel.move(existingIndex, i, 1);
            }
        }
    }

    function requestSearchResults(offset) {
        if (!searchBotUserId) {
            searchQueued = true;
            tdLibWrapper.searchPublicChat(searchBotUserName, false);
            return;
        }
        searchQueued = false;
        isLoading = true;
        searchExtra = "animationSearch|" + searchQuery + "|" + offset;
        tdLibWrapper.getInlineQueryResults(searchBotUserId, chatId, ({}), searchQuery, offset, searchExtra);
    }

    onSearchQueryChanged: {
        // A new query invalidates what an older one may still deliver
        searchExtra = "";
        nextOffset = "";
        isLoading = false;
        searchResultsModel.clear();
        if (searching) {
            searchTimer.restart();
        } else {
            searchTimer.stop();
        }
    }

    onCurrentChanged: {
        if (!current) {
            searchField.focus = false;
        }
    }

    Component.onCompleted: fillSavedAnimations()

    ListModel {
        id: savedAnimationsModel
        dynamicRoles: true
    }

    ListModel {
        id: searchResultsModel
        dynamicRoles: true
    }

    Timer {
        id: searchTimer
        interval: 600
        onTriggered: requestSearchResults("")
    }

    Connections {
        target: stickerManager
        onSavedAnimationsChanged: fillSavedAnimations()
    }

    Connections {
        target: tdLibWrapper
        onChatReceived: {
            if (chat["@extra"] === "searchPublicChat:" + animationPicker.searchBotUserName && chat.type["@type"] === "chatTypePrivate") {
                animationPicker.searchBotUserId = chat.type.user_id;
                if (animationPicker.searchQueued && animationPicker.searching) {
                    animationPicker.requestSearchResults("");
                }
            }
        }
        onInlineQueryResults: {
            if (extra !== animationPicker.searchExtra) {
                return;
            }
            animationPicker.isLoading = false;
            animationPicker.nextOffset = nextOffset;
            for (var i = 0; i < results.length; i++) {
                if (results[i]["@type"] === "inlineQueryResultAnimation") {
                    searchResultsModel.append({ "animation": results[i].animation });
                }
            }
        }
        onErrorReceived: {
            if (extra === animationPicker.searchExtra) {
                animationPicker.isLoading = false;
                animationPicker.nextOffset = "";
            }
        }
    }

    SearchField {
        id: searchField
        width: parent.width
        placeholderText: qsTr("Search GIFs")
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: focus = false
    }

    SilicaGridView {
        id: animationsGridView
        anchors {
            top: searchField.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true

        readonly property int columns: chatPage.isPortrait ? 2 : 3
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.floor(cellWidth * 0.75)

        model: animationPicker.searching ? searchResultsModel : savedAnimationsModel
        delegate: AnimationPickerItem {
            animation: model.animation
            onClicked: animationPicker.animationPicked(model.animation)
            onSendRequested: animationPicker.animationPicked(model.animation)
        }

        onAtYEndChanged: {
            if (atYEnd && animationPicker.searching && animationPicker.nextOffset !== "" && !animationPicker.isLoading) {
                animationPicker.requestSearchResults(animationPicker.nextOffset);
            }
        }

        footer: Item {
            width: animationsGridView.width
            height: animationPicker.isLoading ? Theme.itemSizeLarge : 0
            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Medium
                running: animationPicker.isLoading
            }
        }

        ViewPlaceholder {
            enabled: animationsGridView.count === 0 && !animationPicker.isLoading && !searchTimer.running
            text: animationPicker.searching ? qsTr("No GIFs found") : qsTr("No saved GIFs")
            hintText: animationPicker.searching ? "" : qsTr("Search for one above, or add one from a chat through its menu")
        }

        VerticalScrollDecorator {}
    }
}
