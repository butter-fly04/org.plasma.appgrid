import QtQuick
import QtQuick.Dialogs
import org.kde.iconthemes as KIconThemes

// System icon chooser + custom image chooser. Loaded through a Loader by the General page so a
// missing module only disables the buttons (the page then offers a plain text field instead).
Item {
    id: picker

    signal iconChosen(string name)
    signal imageChosen(string url)

    function chooseIcon() {
        iconDialog.open()
    }

    function chooseImage() {
        imageDialog.open()
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: iconName => {
            if (iconName.length > 0) {
                picker.iconChosen(iconName)
            }
        }
    }

    FileDialog {
        id: imageDialog
        title: "Choose an image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg *.svgz)", "All files (*)"]
        onAccepted: picker.imageChosen(selectedFile.toString())
    }
}
