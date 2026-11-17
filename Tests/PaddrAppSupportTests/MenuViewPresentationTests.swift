import AppKit
import SwiftUI
import XCTest

import PaddrAppSupport
@testable import PaddrMenu
import PaddrCore

@MainActor
final class MenuViewPresentationTests: XCTestCase {
    func testRearButtonCardFitsAdaptiveWidths() async {
        for width in [CGFloat(600), CGFloat(1200)] {
            let host = NSHostingView(rootView: RearButtonConfigurationView(
                configuration: .constant(.unassigned), isEditable: false
            ).frame(width: width))
            host.frame = NSRect(x: 0, y: 0, width: width, height: 600)
            await settle(host)
            XCTAssertLessThanOrEqual(host.fittingSize.width, width + 0.5)
            XCTAssertGreaterThan(host.fittingSize.height, 0)
            XCTAssertLessThan(host.fittingSize.height, 600)
        }
    }

    func testOptionalOutputPickerPreservesRawCodesAndBindingWrites() {
        var selected: String? = "code:122"
        let picker = OptionalOutputBindingPicker(
            selection: Binding(get: { selected }, set: { selected = $0 }),
            title: "Left rear button L4 action"
        )
        XCTAssertEqual(picker.customSelection, "code:122")
        picker.selection = "f1"
        XCTAssertEqual(selected, "f1")
        XCTAssertNil(picker.customSelection)
        picker.selection = TapBindingCatalog.leftMouseButton
        XCTAssertEqual(selected, TapBindingCatalog.leftMouseButton)
        XCTAssertNil(picker.customSelection)
        picker.selection = nil
        XCTAssertNil(selected)
        XCTAssertNil(picker.customSelection)
    }

    func testPendingProfileActionsCaptureKindIDAndDisplayedName() {
        let id = ConfigurationProfileID(
            rawValue: "00000000-0000-0000-0000-000000000501"
        )

        XCTAssertEqual(
            PendingProfileAction.rename(id: id, name: "Original"),
            PendingProfileAction(kind: .rename, profileID: id, profileName: "Original")
        )
        XCTAssertEqual(
            PendingProfileAction.delete(id: id, name: "Original"),
            PendingProfileAction(kind: .delete, profileID: id, profileName: "Original")
        )
        XCTAssertEqual(
            PendingProfileAction.create(suggestedName: "New Profile"),
            PendingProfileAction(
                kind: .create,
                profileID: nil,
                profileName: "New Profile"
            )
        )
    }

    func testFamilyWindowChromeUsesFullSizeTransparentSeparatorlessTitlebar() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize),
            styleMask: PaddrFamilyWindowChrome.styleMask,
            backing: .buffered,
            defer: false
        )

        PaddrFamilyWindowChrome.apply(to: window)

        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
    }

    func testConfigurationWindowMetricsDescribeUsableLayoutWithCompactToolbar() {
        let window = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        let delegate = WindowDelegateProbe()
        window.delegate = delegate

        PaddrFamilyWindowChrome.apply(to: window)
        PaddrFamilyWindowChrome.setUsableLayoutSize(
            PaddrStyle.Metrics.defaultWindowSize,
            for: window
        )
        PaddrFamilyWindowChrome.setMinimumUsableLayoutSize(
            PaddrStyle.Metrics.minimumWindowSize,
            for: window
        )
        window.contentView?.layoutSubtreeIfNeeded()

        XCTAssertNotNil(window.toolbar)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
        assertSize(window.contentLayoutRect.size, equals: PaddrStyle.Metrics.defaultWindowSize)

        window.setContentSize(window.contentMinSize)
        window.contentView?.layoutSubtreeIfNeeded()

        assertSize(window.contentLayoutRect.size, equals: PaddrStyle.Metrics.minimumWindowSize)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertTrue(window.delegate === delegate)
    }

    func testConfigurationWindowUsesTheSystemTitleAndMarksUnsavedChangesAsEdited() async throws {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)

        let window = PaddrFamilyWindowChrome.makeConfigurationWindow(
            rootView: ConfigurationView(model: model))
        defer { window.close() }
        await settle(window)

        XCTAssertEqual(window.title, "Paddr")
        XCTAssertEqual(window.titleVisibility, .visible, "The product name is the system window title")
        XCTAssertTrue(window.titlebarAccessoryViewControllers.isEmpty,
            "No custom title label competes with the toolbar")
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
        XCTAssertFalse(window.isDocumentEdited)
        XCTAssertEqual(window.subtitle, "")

        model.configuration.left.sensitivity += 1
        XCTAssertTrue(model.hasUnsavedChanges)
        await settle(window)
        XCTAssertTrue(window.isDocumentEdited, "Unsaved changes show the dot in the close button")
        XCTAssertEqual(window.subtitle, "Edited")

        XCTAssertTrue(model.revertToSaved())
        await settle(window)
        XCTAssertFalse(window.isDocumentEdited)
        XCTAssertEqual(window.subtitle, "")
    }

    /// The production window around an editable two-profile model.
    private func makeProfileWindowFixture(
        setupGuide: SetupGuidePresentation? = nil, saveProfiles: (@Sendable (ConfigurationProfileDocument) throws -> Void)? = nil
    ) async throws -> (model: PaddrMenuModel, window: NSWindow) {
        var document = ConfigurationProfileDocument.default
        let profile = try document.createProfile(named: "Editable")
        _ = try document.createProfile(named: "Other")
        try document.activateProfile(id: profile.id)
        let loadedDocument = document
        let model = PaddrMenuModel(dependencies: MenuDependencies(
            session: InertSession(),
            loadProfiles: { ConfigurationProfileLoadResult(document: loadedDocument) },
            saveProfiles: saveProfiles ?? { _ in },
            probeReceiver: { nil },
            accessibilityTrusted: { _ in true },
            openPrivacySettings: { _ in },
            sleep: { duration in try await Task.sleep(for: duration) },
            reconnectDelay: { _ in throw CancellationError() }
        ))
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        let window = PaddrFamilyWindowChrome.makeConfigurationWindow(
            rootView: ConfigurationView(model: model, setupGuide: setupGuide)
                .environment(\.accessibilityEnabled, true))
        window.makeKeyAndOrderFront(nil)
        await settle(window)
        return (model, window)
    }

    /// The menu a toolbar item offers, found by one of its commands.
    private func toolbarMenu(in window: NSWindow, containing title: String) -> NSMenu? {
        (window.toolbar?.items ?? []).compactMap { $0.menuFormRepresentation?.submenu }
            .first { $0.items.contains { $0.title == title } }
    }

    private func sheetButtons(of window: NSWindow) -> [NSButton] {
        func buttons(_ view: NSView) -> [NSButton] {
            ((view as? NSButton).map { [$0] } ?? []) + view.subviews.flatMap(buttons)
        }
        return window.attachedSheet?.contentView.map(buttons) ?? []
    }

    /// Chooses a command from the toolbar menu that currently offers it. SwiftUI
    /// rebuilds these menus as state changes, so the menu is looked up each time.
    private func choose(_ title: String, in window: NSWindow) throws {
        let menu = try XCTUnwrap(toolbarMenu(in: window, containing: title), title)
        menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == title }, title))
    }

    func testToolbarPickerAsksBeforeDiscardingADraftAndFollowsTheAnswer() async throws {
        let (model, window) = try await makeProfileWindowFixture()
        defer { window.close() }
        model.configuration.left.sensitivity = 9
        func picker() -> NSMenu? { toolbarMenu(in: window, containing: "Other") }
        func checked() -> [String] { (picker()?.items ?? []).filter { $0.state == .on }.map(\.title) }
        XCTAssertEqual(picker()?.items.map(\.title), ["Default", "Editable", "Other"])
        XCTAssertEqual(checked(), ["Editable"], "Control")

        try choose("Other", in: window)
        await settle(window)
        XCTAssertEqual(model.activeProfile.name, "Editable", "The draft blocks the switch until it is confirmed")
        XCTAssertEqual(sheetButtons(of: window).map(\.title), ["Discard Changes", "Cancel"])
        try XCTUnwrap(sheetButtons(of: window).first { $0.title == "Cancel" }).performClick(nil)
        await settle(window)
        XCTAssertNil(window.attachedSheet)
        XCTAssertEqual(model.activeProfile.name, "Editable")
        XCTAssertTrue(model.hasUnsavedChanges, "Cancelling keeps the draft")
        XCTAssertEqual(checked(), ["Editable"],
            "The picker shows the profile that is still active after a cancelled switch")

        try choose("Other", in: window)
        await settle(window)
        try XCTUnwrap(sheetButtons(of: window).first { $0.title == "Discard Changes" }).performClick(nil)
        let switched = await waitUntil { model.activeProfile.name == "Other" && !model.hasUnsavedChanges }
        XCTAssertTrue(switched, "Discarding performs the switch")
        await settle(window)
        XCTAssertEqual(checked(), ["Other"])
    }

    func testRevertToSavedRunsFromTheToolbarMenuOnlyThroughItsConfirmation() async throws {
        let (model, window) = try await makeProfileWindowFixture()
        defer { window.close() }
        func item(_ title: String) throws -> NSMenuItem {
            try XCTUnwrap(toolbarMenu(in: window, containing: title)?.items.first { $0.title == title })
        }
        XCTAssertFalse(try item("Revert to Saved").isEnabled, "A clean profile has nothing to revert")

        let saved = model.configuration
        model.configuration.left.sensitivity = 9
        await settle(window)
        XCTAssertTrue(try item("Revert to Saved").isEnabled)

        try choose("Revert to Saved", in: window)
        await settle(window)
        XCTAssertEqual(sheetButtons(of: window).map(\.title), ["Revert to Saved", "Cancel"])
        XCTAssertEqual(model.configuration.left.sensitivity, 9, "Asking does not discard anything")
        try XCTUnwrap(sheetButtons(of: window).first { $0.title == "Cancel" }).performClick(nil)
        await settle(window)
        XCTAssertNil(window.attachedSheet)
        XCTAssertEqual(model.configuration.left.sensitivity, 9, "Cancel keeps the draft")

        try choose("Revert to Saved", in: window)
        await settle(window)
        try XCTUnwrap(sheetButtons(of: window).first { $0.title == "Revert to Saved" }).performClick(nil)
        await settle(window)
        XCTAssertEqual(model.configuration, saved)
        XCTAssertFalse(model.hasUnsavedChanges)
        XCTAssertFalse(try item("Revert to Saved").isEnabled)
    }

    func testRenderedProfileMenuDisablesExactlyTheGatedCommands() async throws {
        let (model, window) = try await makeProfileWindowFixture()
        defer { window.close() }
        func menu() -> NSMenu? { toolbarMenu(in: window, containing: "Delete Profile") }
        func disabled() -> [String] {
            (menu()?.items ?? []).filter { !$0.title.isEmpty && !$0.isEnabled }.map(\.title)
        }
        XCTAssertEqual(menu()?.items.map(\.title).filter { !$0.isEmpty },
            ["New Profile", "Duplicate Profile", "Rename Profile", "Revert to Saved", "Restore Defaults",
             "Delete Profile"])
        XCTAssertEqual(disabled(), ["Revert to Saved"])

        model.configuration.left.sensitivity = 9
        await settle(window)
        XCTAssertEqual(disabled(), ["New Profile", "Duplicate Profile", "Delete Profile"],
            "A draft blocks the commands that would replace it")
        let profileCount = model.profiles.count
        try choose("New Profile", in: window)
        try choose("Delete Profile", in: window)
        await settle(window)
        XCTAssertNil(window.attachedSheet, "A disabled command opens nothing")
        XCTAssertEqual(model.profiles.count, profileCount)
        XCTAssertEqual(model.activeProfile.name, "Editable")

        try choose("Rename Profile", in: window)
        await settle(window)
        XCTAssertNotNil(window.attachedSheet, "Control: an enabled command runs")
    }

    func testToolbarKeepsEveryControlVisibleAtTheMinimumWidthAndSavesWithCommandS() async throws {
        let (model, window) = try await makeProfileWindowFixture()
        defer { window.close() }
        PaddrFamilyWindowChrome.setUsableLayoutSize(PaddrStyle.Metrics.minimumWindowSize, for: window)
        model.configuration.left.sensitivity = 9
        await settle(window)
        XCTAssertEqual(window.frame.width, PaddrStyle.Metrics.minimumWindowSize.width, accuracy: 0.5)
        XCTAssertEqual(window.subtitle, "Edited", "Control: the title is at its widest")
        let toolbar = try XCTUnwrap(window.toolbar)
        XCTAssertEqual(toolbar.items.count, 4)
        XCTAssertEqual(toolbar.visibleItems?.map(\.itemIdentifier), toolbar.items.map(\.itemIdentifier),
            "Nothing collapses into the overflow menu at the narrowest window")

        func commandS() throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "s",
                charactersIgnoringModifiers: "s", isARepeat: false, keyCode: 1))
        }
        XCTAssertTrue(window.performKeyEquivalent(with: try commandS()))
        let saved = await waitUntil { !model.hasUnsavedChanges }
        XCTAssertTrue(saved, "Command-S saves from the toolbar item")
        XCTAssertEqual(model.savedConfiguration.left.sensitivity, 9)
        await settle(window)
        XCTAssertFalse(window.performKeyEquivalent(with: try commandS()),
            "With nothing to save the shortcut is not claimed")
    }

    func testAskingForSetupShowsItInTheWindowAndScrollsItIntoView() async throws {
        let suiteName = "MenuViewPresentationTests.setup-window.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let setup = SetupGuidePresentation(preferences: OnboardingPreferences(defaults: defaults))
        let (_, window) = try await makeProfileWindowFixture(setupGuide: setup)
        defer { window.close() }
        PaddrFamilyWindowChrome.setUsableLayoutSize(PaddrStyle.Metrics.minimumWindowSize, for: window)
        let content = try XCTUnwrap(window.contentView)
        await settle(content)
        let scroll = try XCTUnwrap(descendants(of: NSScrollView.self, in: content).first { $0.documentView != nil })
        let document = try XCTUnwrap(scroll.documentView)
        let withoutSetup = document.bounds.height
        let top = scroll.contentView.bounds.origin.y

        scroll.contentView.scroll(to: NSPoint(x: 0, y: top + 240))
        scroll.reflectScrolledClipView(scroll.contentView)
        await settle(content)
        XCTAssertEqual(scroll.contentView.bounds.origin.y, top + 240, accuracy: 1, "Control: the window is scrolled")

        setup.present(trigger: .help)
        let grew = await waitUntil { document.bounds.height > withoutSetup + 100 }
        XCTAssertTrue(grew, "The checklist joins the window's document")
        await settle(content)
        XCTAssertEqual(scroll.contentView.bounds.origin.y, top, accuracy: 1,
            "Asking for setup from a scrolled window brings the checklist into view")

        scroll.contentView.scroll(to: NSPoint(x: 0, y: top + 240))
        scroll.reflectScrolledClipView(scroll.contentView)
        await settle(content)
        setup.present(trigger: .help)
        await settle(content)
        XCTAssertEqual(scroll.contentView.bounds.origin.y, top, accuracy: 1,
            "Asking again while it is showing scrolls back to it")

        setup.dismiss(as: .skipped)
        let shrank = await waitUntil { abs(document.bounds.height - withoutSetup) < 1 }
        XCTAssertTrue(shrank, "Dismissing removes it from the document")
    }

    func testConfigurationToolbarHoldsProfileControlsAndTheSingleSaveAction() async throws {
        var document = ConfigurationProfileDocument.default
        let profile = try document.createProfile(named: "Editable")
        try document.activateProfile(id: profile.id)
        let loadedDocument = document
        let store = BlockingProfileStore()
        store.releaseSave()
        let model = PaddrMenuModel(dependencies: MenuDependencies(
            session: InertSession(),
            loadProfiles: { ConfigurationProfileLoadResult(document: loadedDocument) },
            saveProfiles: store.save,
            probeReceiver: { nil },
            accessibilityTrusted: { _ in true },
            openPrivacySettings: { _ in },
            sleep: { duration in try await Task.sleep(for: duration) },
            reconnectDelay: { _ in throw CancellationError() }
        ))
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)

        let window = PaddrFamilyWindowChrome.makeConfigurationWindow(
            rootView: ConfigurationView(model: model).environment(\.accessibilityEnabled, true))
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        await settle(window)

        let toolbar = try XCTUnwrap(window.toolbar)
        func toolbarElement(_ identifier: String) -> AnyObject? {
            toolbar.items.lazy.compactMap { $0.view }
                .compactMap { self.accessibilityElement(in: $0, identifier: identifier) }.first
        }
        let order = toolbar.items.map { item -> String in
            if item.itemIdentifier == .flexibleSpace { return "space" }
            for identifier in ["paddr.profile.selector", "paddr.profile.actions", "paddr.profile.save-apply"] {
                if let view = item.view, accessibilityElement(in: view, identifier: identifier) != nil {
                    return identifier
                }
            }
            return "unknown"
        }
        XCTAssertEqual(order,
            ["paddr.profile.selector", "paddr.profile.actions", "space", "paddr.profile.save-apply"],
            "Profile controls share the principal position; the one save action stands alone at the trailing edge")
        XCTAssertNil(accessibilityElement(in: try XCTUnwrap(window.contentView), identifier: "paddr.profile.save-apply"),
            "The workspace carries no second header band")

        let picker = try XCTUnwrap(toolbarElement("paddr.profile.selector"))
        XCTAssertEqual(picker.accessibilityLabel?(), "Profile")
        let actions = try XCTUnwrap(toolbarElement("paddr.profile.actions"))
        // A toolbar menu button reports its name as the title.
        XCTAssertEqual(accessibilityText(actions, "accessibilityTitle"), "Profile actions")

        let save = try XCTUnwrap(toolbarElement("paddr.profile.save-apply"))
        XCTAssertEqual(save.accessibilityLabel?(), "Save & Apply")
        XCTAssertEqual(save.accessibilityRole?(), .button)
        XCTAssertEqual(save.isAccessibilityEnabled?(), false, "Nothing to save yet")

        model.configuration.left.sensitivity += 1
        await settle(window)
        let enabledSave = try XCTUnwrap(toolbarElement("paddr.profile.save-apply"))
        XCTAssertEqual(enabledSave.isAccessibilityEnabled?(), true)
        XCTAssertEqual(enabledSave.accessibilityPerformPress?(), true)
        let saved = await waitUntil { !model.hasUnsavedChanges }
        XCTAssertTrue(saved, "The toolbar button runs the model's save and apply")
        XCTAssertEqual(model.status, .configurationSaved)
    }

    func testProfileActionsKeepItemGatesAndNameTheReasonForEveryDisabledCommand() {
        let clean = ProfileActionsPresentation(isDefaultProfile: false, hasUnsavedChanges: false,
            canEditActiveProfile: true, canRevertToSaved: false)
        XCTAssertEqual(clean.items.map(\.id),
            [.new, .duplicate, .rename, .revertToSaved, .restoreDefaults, .delete])
        XCTAssertEqual(clean.items.filter { !$0.isEnabled }.map(\.id), [.revertToSaved])
        XCTAssertEqual(clean.item(.revertToSaved)?.disabledReason.map { String(localized: $0) },
            "There are no unsaved changes to revert")

        let draft = ProfileActionsPresentation(isDefaultProfile: false, hasUnsavedChanges: true,
            canEditActiveProfile: true, canRevertToSaved: true)
        XCTAssertEqual(draft.items.filter { !$0.isEnabled }.map(\.id), [.new, .duplicate, .delete])
        for action in [ProfileAction.new, .duplicate, .delete] {
            XCTAssertEqual(draft.item(action)?.disabledReason.map { String(localized: $0) },
                "Save or revert your changes first")
        }
        XCTAssertEqual(draft.item(.revertToSaved)?.isEnabled, true,
            "A draft can always be discarded for the saved profile")

        let readOnly = ProfileActionsPresentation(isDefaultProfile: true, hasUnsavedChanges: false,
            canEditActiveProfile: false, canRevertToSaved: false)
        XCTAssertEqual(readOnly.items.prefix(2).map(\.id), [.duplicate, .new],
            "Duplicating Default leads while Default is active")
        XCTAssertEqual(String(localized: try! XCTUnwrap(readOnly.item(.duplicate)).title),
            "Duplicate Default to Edit")
        for action in [ProfileAction.rename, .restoreDefaults, .delete] {
            XCTAssertEqual(readOnly.item(action)?.disabledReason.map { String(localized: $0) },
                "Default is read-only")
        }

        let recovered = ProfileActionsPresentation(isDefaultProfile: false, hasUnsavedChanges: true,
            canEditActiveProfile: true, canRevertToSaved: false)
        XCTAssertEqual(recovered.item(.new)?.disabledReason.map { String(localized: $0) },
            "Save this profile first",
            "A profile that only needs saving is never told to revert edits it does not have")
        XCTAssertEqual(recovered.item(.revertToSaved)?.disabledReason.map { String(localized: $0) },
            "There are no unsaved changes to revert")

        let busy = ProfileActionsPresentation(isDefaultProfile: false, hasUnsavedChanges: false,
            canEditActiveProfile: false, canRevertToSaved: false)
        for action in [ProfileAction.rename, .restoreDefaults, .delete] {
            XCTAssertEqual(busy.item(action)?.disabledReason.map { String(localized: $0) },
                "Wait for the profile operation to finish")
        }
        let readOnlyDraft = ProfileActionsPresentation(isDefaultProfile: true, hasUnsavedChanges: true,
            canEditActiveProfile: false, canRevertToSaved: true)
        XCTAssertEqual(readOnlyDraft.item(.delete)?.disabledReason.map { String(localized: $0) },
            "Default is read-only", "What can never be done outranks what must be done first")

        for isDefault in [false, true] {
            for hasChanges in [false, true] {
                for canEdit in [false, true] {
                    for canRevert in [false, true] {
                        let presentation = ProfileActionsPresentation(isDefaultProfile: isDefault,
                            hasUnsavedChanges: hasChanges, canEditActiveProfile: canEdit,
                            canRevertToSaved: canRevert)
                        XCTAssertEqual(Set(presentation.items.map(\.id)), Set(ProfileAction.allCases))
                        for item in presentation.items {
                            XCTAssertEqual(item.isEnabled, item.disabledReason == nil,
                                "Every disabled command names its reason; an enabled one has none")
                            XCTAssertEqual(item.isDestructive, item.id == .delete)
                        }
                    }
                }
            }
        }
    }

    func testSaveAndApplyHelpSaysWhatItDoesOrWhyItCannot() {
        func help(canSave: Bool, hasUnsavedChanges: Bool, isSaving: Bool) -> String {
            String(localized: SaveAndApplyButton.help(
                canSave: canSave, hasUnsavedChanges: hasUnsavedChanges, isSaving: isSaving))
        }
        XCTAssertEqual(help(canSave: true, hasUnsavedChanges: true, isSaving: false),
            "Save this profile and apply it to output")
        XCTAssertEqual(help(canSave: false, hasUnsavedChanges: false, isSaving: false),
            "There are no unsaved changes")
        XCTAssertEqual(help(canSave: false, hasUnsavedChanges: true, isSaving: true),
            "Wait for the profile operation to finish")
        XCTAssertEqual(help(canSave: false, hasUnsavedChanges: true, isSaving: false),
            "Saving is unavailable right now")
    }

    func testRevertToSavedAsksBeforeDiscardingAndOnlyWhenThereIsADraft() async {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        let commands = ProfileCommands()

        commands.perform(.revertToSaved, in: model)
        XCTAssertFalse(commands.showsRevertConfirmation, "Nothing to revert, nothing to confirm")

        let saved = model.configuration
        model.configuration.left.sensitivity += 1
        let draft = model.configuration
        commands.perform(.revertToSaved, in: model)
        XCTAssertTrue(commands.showsRevertConfirmation)
        XCTAssertEqual(model.configuration, draft, "The draft survives until the confirmation is accepted")

        XCTAssertTrue(model.revertToSaved())
        XCTAssertEqual(model.configuration, saved)
    }

    func testLegacyAutosavedPhysicalFrameRetainsUsableSizeAndPositionWithFamilyChrome() {
        let autosaveName = "PaddrConfigurationWindow.v4.Tests.\(UUID().uuidString)"
        let legacyUsableSize = NSSize(width: 868, height: 680)
        defer { NSWindow.removeFrame(usingName: autosaveName) }

        let legacyWindow = makeWindow(hasToolbar: true, usesFullSizeContent: false)
        legacyWindow.setContentSize(legacyUsableSize)
        legacyWindow.center()
        legacyWindow.contentView?.layoutSubtreeIfNeeded()
        let legacyLayoutSize = legacyWindow.contentLayoutRect.size
        let legacyFrame = legacyWindow.frame
        legacyWindow.saveFrame(usingName: autosaveName)

        let familyWindow = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.apply(to: familyWindow)

        XCTAssertTrue(familyWindow.setFrameUsingName(autosaveName))
        let restoredLegacyUsableSize = familyWindow.contentRect(
            forFrameRect: familyWindow.frame
        ).size
        PaddrFamilyWindowChrome.setUsableLayoutSize(
            restoredLegacyUsableSize,
            for: familyWindow
        )
        PaddrFamilyWindowChrome.setMinimumUsableLayoutSize(
            PaddrStyle.Metrics.minimumWindowSize,
            for: familyWindow
        )
        familyWindow.contentView?.layoutSubtreeIfNeeded()

        XCTAssertTrue(familyWindow.frame.isApproximatelyEqual(to: legacyFrame))
        assertSize(familyWindow.contentLayoutRect.size, equals: legacyLayoutSize)
        assertSize(familyWindow.contentLayoutRect.size, equals: legacyUsableSize)
    }

    func testExpandedAutosavedFrameMigratesToCompactWithoutChangingUsableSizeOrTopEdge() {
        let autosaveName = "PaddrConfigurationWindow.v6.Tests.\(UUID().uuidString)"
        let expectedUsableSize = NSSize(width: 868, height: 680)
        defer { NSWindow.removeFrame(usingName: autosaveName) }

        let expandedWindow = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        expandedWindow.toolbarStyle = .unified
        PaddrFamilyWindowChrome.apply(to: expandedWindow)
        PaddrFamilyWindowChrome.setUsableLayoutSize(expectedUsableSize, for: expandedWindow)
        expandedWindow.center()
        expandedWindow.contentView?.layoutSubtreeIfNeeded()
        let expectedTopLeft = NSPoint(
            x: expandedWindow.frame.minX,
            y: expandedWindow.frame.maxY
        )
        expandedWindow.saveFrame(usingName: autosaveName)

        let compactWindow = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.apply(to: compactWindow)

        XCTAssertTrue(
            PaddrFamilyWindowChrome.migrateAutosavedFrame(
                usingName: autosaveName,
                from: .unified,
                to: .unifiedCompact,
                for: compactWindow
            )
        )
        compactWindow.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(compactWindow.toolbarStyle, .unifiedCompact)
        assertSize(compactWindow.contentLayoutRect.size, equals: expectedUsableSize)
        XCTAssertEqual(compactWindow.frame.minX, expectedTopLeft.x, accuracy: 0.5)
        XCTAssertEqual(compactWindow.frame.maxY, expectedTopLeft.y, accuracy: 0.5)
    }

    func testLegacyAutosavedFrameBelowNewMinimumIsEnlargedBeforeDisplay() {
        let autosaveName = "PaddrConfigurationWindow.v5.Tests.\(UUID().uuidString)"
        let legacyUsableSize = NSSize(width: 640, height: 500)
        defer { NSWindow.removeFrame(usingName: autosaveName) }

        let legacyWindow = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.apply(to: legacyWindow)
        PaddrFamilyWindowChrome.setUsableLayoutSize(legacyUsableSize, for: legacyWindow)
        legacyWindow.center()
        legacyWindow.contentView?.layoutSubtreeIfNeeded()
        let expectedTopEdge = legacyWindow.frame.maxY
        legacyWindow.saveFrame(usingName: autosaveName)

        let restoredWindow = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.apply(to: restoredWindow)
        XCTAssertTrue(restoredWindow.setFrameUsingName(autosaveName))

        PaddrFamilyWindowChrome.clampRestoredUsableFrame(
            minimumSize: PaddrStyle.Metrics.minimumWindowSize,
            for: restoredWindow
        )
        restoredWindow.contentView?.layoutSubtreeIfNeeded()

        assertSize(
            restoredWindow.contentLayoutRect.size,
            equals: PaddrStyle.Metrics.minimumWindowSize
        )
        XCTAssertEqual(restoredWindow.frame.maxY, expectedTopEdge, accuracy: 0.5)
    }

    func testV7DefaultAutosavedFrameMigratesToScreenFittedDefault() throws {
        let autosaveName = "PaddrConfigurationWindow.v7.Tests.\(UUID().uuidString)"
        let formerDefault = NSSize(width: 1_280, height: 700)
        defer { NSWindow.removeFrame(usingName: autosaveName) }

        let v7Window = makeWindow(hasToolbar: false, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.apply(to: v7Window)
        PaddrFamilyWindowChrome.setUsableLayoutSize(formerDefault, for: v7Window)
        v7Window.center()
        v7Window.contentView?.layoutSubtreeIfNeeded()
        let expectedTopEdge = v7Window.frame.maxY
        v7Window.saveFrame(usingName: autosaveName)

        let v8Window = makeWindow(hasToolbar: false, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.apply(to: v8Window)
        XCTAssertTrue(
            PaddrFamilyWindowChrome.restoreAutosavedUsableFrame(
                usingName: autosaveName,
                legacyDefaultSize: formerDefault,
                newDefaultSize: PaddrStyle.Metrics.defaultWindowSize,
                minimumSize: PaddrStyle.Metrics.minimumWindowSize,
                for: v8Window
            )
        )
        v8Window.contentView?.layoutSubtreeIfNeeded()

        let expectedSize = PaddrFamilyWindowChrome.fittedDefaultUsableSize(
            PaddrStyle.Metrics.defaultWindowSize,
            minimumSize: PaddrStyle.Metrics.minimumWindowSize,
            visibleFrame: v8Window.screen?.visibleFrame, for: v8Window
        )
        assertSize(v8Window.contentLayoutRect.size, equals: expectedSize)
        let expectedFrame = WindowFrameGeometry.constrainedFrame(
            NSRect(x: v8Window.frame.minX, y: expectedTopEdge - v8Window.frame.height,
                   width: v8Window.frame.width, height: v8Window.frame.height),
            to: try XCTUnwrap(v8Window.screen).visibleFrame
        )
        XCTAssertEqual(v8Window.frame.maxY, expectedFrame.maxY, accuracy: 0.5)
    }

    func testV8DefaultAndCustomFramesMigrateAndPreserveSubsequentResizingOnReopen() {
        for originalSize in [NSSize(width: 1280, height: 760), NSSize(width: 1410, height: 830)] {
            let oldName = "PaddrConfigurationWindow.v8.Tests.\(UUID().uuidString)"
            let newName = "PaddrConfigurationWindow.v9.Tests.\(UUID().uuidString)"
            defer {
                NSWindow.removeFrame(usingName: oldName)
                NSWindow.removeFrame(usingName: newName)
            }
            let original = makeWindow(hasToolbar: false, usesFullSizeContent: true)
            PaddrFamilyWindowChrome.setUsableLayoutSize(originalSize, for: original)
            original.center()
            original.saveFrame(usingName: oldName)
            let migrated = makeWindow(hasToolbar: false, usesFullSizeContent: true)
            XCTAssertTrue(PaddrFamilyWindowChrome.restoreAutosavedUsableFrame(
                usingName: oldName, legacyDefaultSize: NSSize(width: 1280, height: 760),
                newDefaultSize: PaddrStyle.Metrics.defaultWindowSize,
                minimumSize: PaddrStyle.Metrics.minimumWindowSize, for: migrated
            ))
            let expected = originalSize.width == 1280
                ? PaddrFamilyWindowChrome.fittedDefaultUsableSize(
                    PaddrStyle.Metrics.defaultWindowSize,
                    minimumSize: PaddrStyle.Metrics.minimumWindowSize,
                    visibleFrame: migrated.screen?.visibleFrame, for: migrated)
                : originalSize
            assertSize(migrated.contentLayoutRect.size, equals: expected)
            let customSize = NSSize(width: 1100, height: 720)
            PaddrFamilyWindowChrome.setUsableLayoutSize(customSize, for: migrated)
            migrated.saveFrame(usingName: newName)
            for _ in 0..<3 {
                let reopened = makeWindow(hasToolbar: false, usesFullSizeContent: true)
                XCTAssertTrue(reopened.setFrameUsingName(newName))
                assertSize(reopened.contentLayoutRect.size, equals: customSize)
                reopened.saveFrame(usingName: newName)
            }
        }
    }

    func testManagedWindowDiscardsSavedSizeAndDisablesManualResizing() {
        let autosaveName = "PaddrConfigurationWindow.v10.Tests.\(UUID().uuidString)"
        defer { NSWindow.removeFrame(usingName: autosaveName) }
        let window = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        // Simulate the tall geometry seen in the report before applying the new policy.
        PaddrFamilyWindowChrome.setUsableLayoutSize(NSSize(width: 941, height: 840), for: window)
        PaddrFamilyWindowChrome.restoreConfigurationFrame(for: window, autosaveName: autosaveName)
        let expected = PaddrFamilyWindowChrome.fittedDefaultUsableSize(
            PaddrStyle.Metrics.defaultWindowSize, minimumSize: PaddrStyle.Metrics.minimumWindowSize,
            visibleFrame: window.screen?.visibleFrame, for: window)
        assertSize(window.contentLayoutRect.size, equals: expected)

        let custom = NSSize(width: 960, height: 720)
        PaddrFamilyWindowChrome.setUsableLayoutSize(custom, for: window)
        window.saveFrame(usingName: autosaveName)
        // AppKit assigns only one live window to an autosave name.
        window.setFrameAutosaveName("")
        let reopened = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.restoreConfigurationFrame(for: reopened, autosaveName: autosaveName)
        assertSize(reopened.contentLayoutRect.size, equals: expected)
        XCTAssertFalse(reopened.styleMask.contains(.resizable))

        PaddrFamilyWindowChrome.setFreshDefaultUsableFrame(for: reopened)
        assertSize(reopened.contentLayoutRect.size, equals: expected)
        reopened.setFrameAutosaveName("")
    }

    func testManagedWindowScreenCapAndTopEdgeRemainStable() {
        let window = makeWindow(hasToolbar: true, usesFullSizeContent: true)
        window.contentMinSize = .zero
        let screen = NSRect(x: 0, y: 40, width: 1200, height: 800)
        PaddrFamilyWindowChrome.setUsableLayoutSize(NSSize(width: 1080, height: 500), for: window)
        window.setFrameTopLeftPoint(NSPoint(x: 50, y: screen.maxY))
        PaddrFamilyWindowChrome.fitConfigurationWindow(window, preferredHeight: 1100, visibleFrame: screen)
        XCTAssertEqual(window.contentLayoutRect.width, PaddrStyle.Metrics.defaultWindowSize.width, accuracy: 0.5,
            "Managed opening must discard the former 1080-point width")
        XCTAssertEqual(window.frame.maxY, screen.maxY, accuracy: 0.5)
        XCTAssertEqual(window.frame.minY, screen.minY, accuracy: 0.5)
        XCTAssertTrue(screen.contains(window.frame))
        PaddrFamilyWindowChrome.fitConfigurationWindow(window, preferredHeight: 500, visibleFrame: screen)
        XCTAssertEqual(window.contentLayoutRect.height, 500, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, screen.maxY, accuracy: 0.5)
    }

    func testFreshDefaultFitsActualScreenAndRetainsUsableMinimum() {
        let window = makeWindow(hasToolbar: false, usesFullSizeContent: true)
        PaddrFamilyWindowChrome.setFreshDefaultUsableFrame(for: window)
        guard let screen = window.screen?.visibleFrame else {
            return XCTFail("A screen is required for window presentation tests")
        }
        assertSize(window.contentLayoutRect.size, equals:
            PaddrFamilyWindowChrome.fittedDefaultUsableSize(
                PaddrStyle.Metrics.defaultWindowSize,
                minimumSize: PaddrStyle.Metrics.minimumWindowSize,
                visibleFrame: screen, for: window))
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.width, 680)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.height, 600)
        XCTAssertLessThanOrEqual(window.frame.maxY, screen.maxY + 0.5)
    }

    func testScreenFitMeasuresInstalledTitleChromeForOversizedDefault() {
        let window = makeWindow(hasToolbar: false, usesFullSizeContent: true)
        let requestedSize = NSSize(width: 1400, height: 1100)
        PaddrFamilyWindowChrome.setUsableLayoutSize(requestedSize, for: window)
        let screen = NSRect(x: -1200, y: 40, width: 1200, height: 900)
        let size = PaddrFamilyWindowChrome.fittedDefaultUsableSize(
            requestedSize,
            minimumSize: PaddrStyle.Metrics.minimumWindowSize,
            visibleFrame: screen, for: window
        )
        PaddrFamilyWindowChrome.setUsableLayoutSize(size, for: window)
        XCTAssertEqual(window.frame.width, screen.width, accuracy: 0.5)
        XCTAssertEqual(window.frame.height, screen.height, accuracy: 0.5)
        XCTAssertLessThan(size.height, screen.height)
    }

    func testSetupChecklistLivesInTheConfigurationWindowAndDismissalRecordsIt() async throws {
        let suiteName = "MenuViewPresentationTests.setup.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = OnboardingPreferences(defaults: defaults)
        let setup = SetupGuidePresentation(preferences: preferences)
        setup.present(trigger: .automatic)

        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: MenuDependencies(
            session: InertSession(),
            loadProfiles: { ConfigurationProfileLoadResult(document: .default) },
            saveProfiles: store.save,
            probeReceiver: { nil },
            accessibilityTrusted: { _ in false },
            inputMonitoringAccess: { _ in .denied },
            openPrivacySettings: { _ in },
            sleep: { duration in try await Task.sleep(for: duration) },
            reconnectDelay: { _ in throw CancellationError() }
        ))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        XCTAssertFalse(model.hasSystemAccess)

        // The scroll document is hosted directly; the window around it supplies the bar.
        let commands = ProfileCommands()
        let host = NSHostingView(rootView: ConfigurationContentView(
            model: model, commands: commands, setupGuide: setup)
            .environment(\.accessibilityEnabled, true))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: NSSize(
                width: PaddrStyle.Metrics.defaultWindowSize.width, height: 1400)),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        await settle(host)

        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.setup"), "Setup is in the one window")
        var stepStates: [String: String] = [:]
        for step in ["access", "connection", "profile", "output"] {
            let element = try XCTUnwrap(
                accessibilityElement(in: host, identifier: "paddr.setup.\(step)"), step)
            // A group reports its state as the value description VoiceOver speaks.
            stepStates[step] = accessibilityText(element, "accessibilityValueDescription")
        }
        XCTAssertEqual(model.readiness.nextAction.setupStep, .connection)
        XCTAssertEqual(stepStates, ["access": "Not done", "connection": "Next step",
                                    "profile": "Not done", "output": "Not done"],
            "The step that owns the next action is the one marked next")
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.setup.input-monitoring.request"),
            "The permission step offers its action in place")
        let stoppedSearching = await waitUntil { !model.isSearchingForPuck }
        XCTAssertTrue(stoppedSearching, "This fixture's reconnect loop ends after its first probe")
        await settle(host)
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.setup.refresh"),
            "A missing puck that nothing polls for offers Refresh beside the instruction")
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.setup.enable-output"))
        XCTAssertEqual(accessibilityElements(in: host, identifier: "paddr.profile.duplicate-to-edit").count, 1,
            "The checklist carries the read-only notice; it is not repeated below")

        let bar = NSHostingView(rootView: ConfigurationView(model: model, setupGuide: setup)
            .environment(\.accessibilityEnabled, true))
        bar.frame = NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize)
        await settle(bar)
        XCTAssertNil(accessibilityElement(in: bar, identifier: "paddr.permissions.open-setup"),
            "The bar does not repeat the permission request while setup shows it")

        let dismiss = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.setup.dismiss"))
        XCTAssertEqual(dismiss.accessibilityLabel?(), "Skip Setup")
        XCTAssertEqual(dismiss.accessibilityPerformPress?(), true)
        await settle(host)
        await settle(bar)

        XCTAssertFalse(setup.isPresented)
        XCTAssertEqual(preferences.dismissal, .skipped)
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.setup"))
        XCTAssertNotNil(accessibilityElement(in: host, identifier: "paddr.profile.read-only-notice"),
            "Without setup, Default still says why its controls are disabled")
        XCTAssertEqual(accessibilityElements(in: host, identifier: "paddr.profile.duplicate-to-edit").count, 1)
        XCTAssertNotNil(accessibilityElement(in: bar, identifier: "paddr.permissions.open-setup"))
    }

    func testReadOnlyNoticeDuplicatesDefaultIntoAnEditableProfile() async throws {
        let store = BlockingProfileStore()
        store.releaseSave()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        XCTAssertEqual(model.activeProfileID, .default)

        let host = NSHostingView(rootView: ConfigurationContentView(model: model, commands: ProfileCommands())
            .environment(\.accessibilityEnabled, true))
        host.frame = NSRect(origin: .zero, size: NSSize(
            width: PaddrStyle.Metrics.defaultWindowSize.width, height: 1200))
        await settle(host)

        let notice = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.profile.read-only-notice"))
        XCTAssertEqual(
            accessibilityText(notice, "accessibilityLabel") ?? accessibilityText(notice, "accessibilityValue"),
            "Default is read-only. Duplicate it to make changes.")
        let duplicate = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.profile.duplicate-to-edit"))
        XCTAssertEqual(duplicate.accessibilityLabel?(), "Duplicate to Edit")
        XCTAssertEqual(duplicate.accessibilityPerformPress?(), true)

        let duplicated = await waitUntil { model.activeProfileID != .default && model.canEditActiveProfile }
        XCTAssertTrue(duplicated)
        await settle(host)
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.profile.read-only-notice"),
            "An editable profile needs no notice")
    }

    func testReadOnlyNoticeWaitsForAProfileOperationAndSaysSo() async throws {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        let commands = ProfileCommands()
        let host = NSHostingView(rootView: ConfigurationContentView(model: model, commands: commands)
            .environment(\.accessibilityEnabled, true))
        host.frame = NSRect(origin: .zero, size: NSSize(
            width: PaddrStyle.Metrics.defaultWindowSize.width, height: 1200))
        await settle(host)
        func duplicate() -> AnyObject? { accessibilityElement(in: host, identifier: "paddr.profile.duplicate-to-edit") }
        XCTAssertEqual(try XCTUnwrap(duplicate()).isAccessibilityEnabled?(), true, "Control")
        XCTAssertNil(ReadOnlyProfileNotice(model: model, commands: commands).disabledReason)

        XCTAssertTrue(model.duplicateActiveProfile())
        let blocked = await waitUntil { store.didStartSave }
        XCTAssertTrue(blocked)
        XCTAssertFalse(model.canManageProfiles, "Control: the first duplication is still saving")
        await settle(host)
        if let button = duplicate() {
            XCTAssertEqual(button.isAccessibilityEnabled?(), false,
                "A second duplication cannot start while the first is in flight")
        }
        XCTAssertEqual(
            ReadOnlyProfileNotice(model: model, commands: commands).disabledReason.map { String(localized: $0) },
            "Wait for the profile operation to finish")
        let profileCount = model.profiles.count
        commands.perform(.duplicate, in: model)
        XCTAssertEqual(model.profiles.count, profileCount, "The command itself refuses, not only the button")

        store.releaseSave()
        let finished = await waitUntil { model.canManageProfiles && model.activeProfileID != .default }
        XCTAssertTrue(finished)
    }

    func testSetupRecordsCompletionWhenOutputBecomesActiveAndKeepsTheChecklist() async throws {
        let suiteName = "MenuViewPresentationTests.setup-complete.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = OnboardingPreferences(defaults: defaults)
        let setup = SetupGuidePresentation(preferences: preferences)
        setup.present(trigger: .automatic)
        let store = BlockingProfileStore()
        store.releaseSave()
        let session = PresentationSession()
        let model = PaddrMenuModel(dependencies: dependencies(store: store, session: session, receiver: "Fake puck"))
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        let started = await waitUntil { await session.startCount == 1 }
        XCTAssertTrue(started)

        let host = NSHostingView(rootView: ConfigurationContentView(
            model: model, commands: ProfileCommands(), setupGuide: setup)
            .environment(\.accessibilityEnabled, true))
        host.frame = NSRect(origin: .zero, size: NSSize(
            width: PaddrStyle.Metrics.defaultWindowSize.width, height: 1400))
        await settle(host)
        let dismiss = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.setup.dismiss"))
        XCTAssertEqual(dismiss.accessibilityLabel?(), "Skip Setup")
        XCTAssertNil(preferences.dismissal, "Control: nothing is recorded while setup is unfinished")

        // Output on but no controller yet: the output step must not ask to turn it on again.
        model.isEnabled = true
        await settle(host)
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.setup.enable-output"))
        XCTAssertTrue(accessibilityTexts(in: host).contains("Output is on. It starts once the steps above are done."))
        XCTAssertFalse(accessibilityTexts(in: host).contains {
            $0.hasPrefix("Turn on output, then release both trackpads")
        })
        XCTAssertNil(preferences.dismissal)

        await session.send(.waitingForController("Fake puck"))
        await session.send(.controllerConnected)
        await session.send(.outputArmed)
        let active = await waitUntil { model.readiness.output == .active }
        XCTAssertTrue(active)
        await settle(host)
        XCTAssertEqual(preferences.dismissal, .completed,
            "Reaching active output ends automatic setup even if Done is never pressed")
        XCTAssertTrue(setup.isPresented, "The checklist stays for the person reading it")
        XCTAssertEqual(try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.setup.dismiss"))
            .accessibilityLabel?(), "Done")
        XCTAssertTrue(accessibilityTexts(in: host).contains("Output is active."))

        model.isEnabled = false
        _ = await session.stop()
    }

    func testSetupChecklistStaysInsideTheNarrowestWindowWithoutAccess() async throws {
        let suiteName = "MenuViewPresentationTests.setup-narrow.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let setup = SetupGuidePresentation(preferences: OnboardingPreferences(defaults: defaults))
        setup.present(trigger: .automatic)
        let model = PaddrMenuModel(dependencies: MenuDependencies(
            session: InertSession(),
            loadProfiles: { ConfigurationProfileLoadResult(document: .default) },
            saveProfiles: { _ in },
            probeReceiver: { nil },
            accessibilityTrusted: { _ in false },
            inputMonitoringAccess: { _ in .denied },
            openPrivacySettings: { _ in },
            sleep: { duration in try await Task.sleep(for: duration) },
            reconnectDelay: { _ in throw CancellationError() }
        ))
        let didInitialize = await waitUntil { model.isInitialized && !model.isSearchingForPuck }
        XCTAssertTrue(didInitialize, "This fixture's reconnect loop ends after its first probe")
        let width = PaddrStyle.Metrics.minimumWindowSize.width
        let host = NSHostingView(rootView: ConfigurationContentView(
            model: model, commands: ProfileCommands(), setupGuide: setup)
            .environment(\.accessibilityEnabled, true))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: NSSize(width: width, height: 1800)),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.orderFront(nil)
        await settle(host)

        let bounds = window.convertToScreen(host.convert(host.bounds, to: nil))
        var checked: [String] = []
        for element in accessibilityElements(in: host, where: { $0.hasPrefix("paddr.setup") || $0.hasPrefix("paddr.profile") }) {
            let identifier = element.accessibilityIdentifier?() ?? ""
            guard let frame = element.accessibilityFrame?(), frame.width > 0 else { continue }
            checked.append(identifier)
            XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.5, identifier)
            XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.5, identifier)
        }
        for required in ["paddr.setup", "paddr.setup.dismiss", "paddr.setup.input-monitoring.request",
                         "paddr.setup.refresh", "paddr.profile.duplicate-to-edit", "paddr.setup.enable-output"] {
            XCTAssertTrue(checked.contains(required), "\(required) is laid out and measured")
        }
    }

    func testBarGuidanceWrapsBelowItsRefreshInsteadOfLeavingANarrowBar() async throws {
        let store = BlockingProfileStore()
        store.releaseSave()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        // This fixture's reconnect loop ends after its first probe, which is the
        // only state that asks for a manual refresh.
        let needsRefresh = await waitUntil { model.readiness.nextAction == .refreshPuck }
        XCTAssertTrue(needsRefresh)

        func frames(width: CGFloat) async throws -> (host: CGRect, label: CGRect, refresh: CGRect) {
            let host = NSHostingView(rootView: ApplyBarView(model: model).frame(width: width)
                .environment(\.accessibilityEnabled, true))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 400),
                styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            window.orderFront(nil)
            await settle(host)
            let label = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.status.next-action"))
            let refresh = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.status.refresh"))
            return (window.convertToScreen(host.convert(host.bounds, to: nil)),
                    try XCTUnwrap(label.accessibilityFrame?()), try XCTUnwrap(refresh.accessibilityFrame?()))
        }

        let wide = try await frames(width: PaddrStyle.Metrics.defaultWindowSize.width)
        XCTAssertEqual(wide.label.midY, wide.refresh.midY, accuracy: 1, "With room, Refresh sits beside its instruction")
        XCTAssertLessThan(wide.label.maxX, wide.refresh.minX)

        // Narrower than the instruction and its button on one line.
        let narrowWidth = wide.label.width + PaddrStyle.Inset.window * 2
        let narrow = try await frames(width: narrowWidth)
        XCTAssertGreaterThanOrEqual(narrow.label.minX, narrow.host.minX - 0.5)
        XCTAssertLessThanOrEqual(narrow.label.maxX, narrow.host.maxX + 0.5, "The instruction stays inside the bar")
        XCTAssertLessThanOrEqual(narrow.refresh.maxX, narrow.host.maxX + 0.5, "Refresh stays inside the bar")
        XCTAssertLessThan(narrow.refresh.maxY, narrow.label.minY, "Refresh drops below the instruction")

        // Too narrow for the instruction itself: it wraps onto more lines.
        let tight = try await frames(width: wide.label.width * 0.6 + PaddrStyle.Inset.window * 2)
        XCTAssertLessThanOrEqual(tight.label.maxX, tight.host.maxX + 0.5)
        XCTAssertGreaterThan(tight.label.height, wide.label.height * 1.5, "The instruction wraps instead of clipping")
    }

    func testDualPadWorkflowMountsTwoPadModeControls() {
        let view = DualPadConfigurationView(
            configuration: .constant(.default),
            appearsEnabled: true,
            isEditable: true
        )
        .frame(width: PaddrStyle.Metrics.defaultContentWidth)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: PaddrStyle.Metrics.defaultContentWidth, height: 620)
        )
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            descendants(of: NSSegmentedControl.self, in: hostingView).count,
            2,
            "Both pad-mode editors must remain mounted together"
        )
    }

    func testFamilyConsoleRendersAtDefaultWindowSize() async throws {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)

        let hostingView = NSHostingView(rootView: ConfigurationView(model: model))
        hostingView.frame = NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize)
        await settle(hostingView)

        XCTAssertEqual(hostingView.bounds.size, PaddrStyle.Metrics.defaultWindowSize)
        XCTAssertGreaterThan(descendants(of: NSControl.self, in: hostingView).count, 2)
        for control in descendants(of: NSControl.self, in: hostingView) {
            let frame = control.convert(control.bounds, to: hostingView)
            XCTAssertGreaterThanOrEqual(frame.minX, hostingView.bounds.minX - 0.5)
            XCTAssertLessThanOrEqual(frame.maxX, hostingView.bounds.maxX + 0.5)
        }

        if let snapshotPath = ProcessInfo.processInfo.environment["PADDR_UI_SNAPSHOT_PATH"] {
            let representation = try XCTUnwrap(
                hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
            let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
        }
    }

    func testFixedSizeFixtureDoesNotAutomaticallyResizeItsWindow() async {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)

        let window = makeWindow(hasToolbar: false, usesFullSizeContent: true)
        let controller = NSHostingController(rootView: ConfigurationView(model: model))
        controller.sizingOptions = []
        window.contentViewController = controller
        PaddrFamilyWindowChrome.apply(to: window)
        PaddrFamilyWindowChrome.setUsableLayoutSize(
            PaddrStyle.Metrics.defaultWindowSize,
            for: window
        )
        let expectedFrame = window.frame

        if let contentView = window.contentView {
            for _ in 0..<12 {
                contentView.layoutSubtreeIfNeeded()
                await Task.yield()
            }
        }

        XCTAssertTrue(window.frame.isApproximatelyEqual(to: expectedFrame))
        assertSize(window.contentLayoutRect.size, equals: PaddrStyle.Metrics.defaultWindowSize)
    }

    func testPaddrAppearanceResolvesEveryAdaptiveCombination() {
        for reduceTransparency in [false, true] {
            for contrast in [ColorSchemeContrast.standard, .increased] {
                for differentiateWithoutColor in [false, true] {
                    for reduceMotion in [false, true] {
                        let appearance = PaddrAppearance(
                            reduceTransparency: reduceTransparency,
                            colorSchemeContrast: contrast,
                            differentiateWithoutColor: differentiateWithoutColor,
                            reduceMotion: reduceMotion
                        )
                        let increased = contrast == .increased
                        XCTAssertEqual(appearance.usesOpaqueFallback, reduceTransparency)
                        XCTAssertEqual(appearance.hasIncreasedContrast, increased)
                        XCTAssertEqual(appearance.showsSurfaceDepth, !reduceTransparency && !increased)
                        XCTAssertEqual(appearance.usesShapeDifferentiation, differentiateWithoutColor)
                        XCTAssertEqual(appearance.reducesMotion, reduceMotion)
                        XCTAssertEqual(appearance.strokeWidth, increased ? 1.5 : 1)
                        XCTAssertEqual(appearance.strokeOpacity(0.46), increased ? 1 : 0.46)
                        XCTAssertEqual(appearance.strokeOpacity(0.18), increased ? 1 : 0.18)
                        XCTAssertEqual(appearance.animation(.default) == nil, reduceMotion)
                        XCTAssertNil(appearance.animation(nil))
                    }
                }
            }
        }
    }

    func testSettingsRowControlsStayWithinTheSharedRowHeightInEveryPadMode() async {
        for width in [PaddrStyle.minimumPadColumnWidth, PaddrStyle.padColumnWidth] {
            for mode in PadMode.allCases {
                for layout in PadZoneLayout.allCases {
                    var configuration = PadConfiguration(mode: mode)
                    configuration.zoneLayout = layout
                    let hostingView = NSHostingView(
                        rootView: PadConfigurationView(
                            side: .left,
                            configuration: .constant(configuration),
                            initialTuningExpanded: true
                        )
                        .frame(width: width)
                    )
                    hostingView.frame = NSRect(
                        origin: .zero,
                        size: NSSize(
                            width: width,
                            height: PaddrStyle.Metrics.defaultWindowSize.height
                        )
                    )
                    await settle(hostingView)

                    for control in descendants(of: NSControl.self, in: hostingView) {
                        XCTAssertLessThanOrEqual(
                            control.bounds.height,
                            PaddrStyle.Metrics.row + 0.5,
                            "\(type(of: control)) in \(mode)/\(layout) at \(width)pt "
                                + "is taller than the row family"
                        )
                        assertControlFits(control, in: hostingView)
                    }
                }
            }
        }
    }

    /// A SwiftUI `Slider` renders no `NSControl` descendant on this SDK, so the switch is
    /// the probe that is actually reachable through the `descendants(of:)` seam.
    func testSettingsRowCentersItsControlInTheSharedRowHeight() throws {
        let row = PaddrSettingsRow(title: "Track pointer") {
            Toggle("Track pointer", isOn: .constant(true))
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .frame(width: PaddrStyle.padColumnWidth)
        let hostingView = NSHostingView(rootView: row)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: PaddrStyle.padColumnWidth,
                height: hostingView.fittingSize.height
            )
        )
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            hostingView.bounds.height,
            PaddrStyle.Metrics.row,
            accuracy: 0.5
        )
        let toggle = try XCTUnwrap(firstDescendant(of: NSControl.self, in: hostingView))
        let frame = toggle.convert(toggle.bounds, to: hostingView)
        XCTAssertLessThanOrEqual(frame.height, PaddrStyle.Metrics.row + 0.5)
        XCTAssertEqual(frame.midY, hostingView.bounds.midY, accuracy: 0.5)
    }

    func testCompactSettingsAlignControlsToTheirLeadingEdge() throws {
        let rows = VStack(spacing: PaddrStyle.Spacing.s3) {
            PaddrSettingsRow(
                title: "Track pointer inside tap radius",
                labelWidth: nil
            ) {
                Toggle("Track pointer inside tap radius", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            PaddrSettingsRow(title: "Touch tap") {
                SettingsControlEdgeProbe(identifier: "picker-edge")
                    .frame(width: PaddrStyle.Width.control)
            }
        }
        .environment(\.paddrStacksSettingLabels, true)
        .frame(width: PaddrStyle.minimumPadSectionWidth)
        let hostingView = NSHostingView(rootView: rows)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: PaddrStyle.minimumPadSectionWidth,
                height: hostingView.fittingSize.height
            )
        )
        hostingView.layoutSubtreeIfNeeded()

        let toggle = try XCTUnwrap(firstDescendant(of: NSSwitch.self, in: hostingView))
        let pickerEdge = try XCTUnwrap(
            descendants(of: NSView.self, in: hostingView).first {
                $0.identifier?.rawValue == "picker-edge"
            }
        )
        XCTAssertEqual(
            toggle.convert(toggle.bounds, to: hostingView).minX,
            pickerEdge.convert(pickerEdge.bounds, to: hostingView).minX,
            accuracy: 1
        )
    }

    func testSettingsGroupAddsItsSeparatingDividerOnlyWhenDeclared() {
        func groupHeight(showsLeadingDivider: Bool) -> CGFloat {
            let group = PaddrSettingsGroup(showsLeadingDivider: showsLeadingDivider) {
                PaddrSettingsRow(title: "Sensitivity") {
                    Slider(value: .constant(0.5), in: 0...1)
                        .frame(width: PaddrStyle.Width.control)
                }
            }
            .frame(width: PaddrStyle.padColumnWidth)
            let hostingView = NSHostingView(rootView: group)
            hostingView.layoutSubtreeIfNeeded()
            return hostingView.fittingSize.height
        }

        XCTAssertGreaterThan(
            groupHeight(showsLeadingDivider: true),
            groupHeight(showsLeadingDivider: false)
        )
    }

    func testWorkspaceOwnsSurfaceMarginWithoutNestedSectionInsets() throws {
        let width: CGFloat = 300
        let contentHeight: CGFloat = 44

        let cardView = SettingsControlEdgeProbe(identifier: "card-content")
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight)
            .paddrCard()
            .frame(width: width)
        let cardHost = NSHostingView(rootView: cardView)
        cardHost.frame = NSRect(origin: .zero, size: cardHost.fittingSize)
        cardHost.layoutSubtreeIfNeeded()
        let cardContent = try XCTUnwrap(
            descendants(of: NSView.self, in: cardHost).first {
                $0.identifier?.rawValue == "card-content"
            }
        )
        let cardFrame = cardContent.convert(cardContent.bounds, to: cardHost)
        XCTAssertEqual(cardHost.bounds.width, width, accuracy: 0.5)
        XCTAssertEqual(
            cardHost.bounds.height,
            contentHeight + (2 * PaddrStyle.Inset.card),
            accuracy: 0.5
        )
        XCTAssertEqual(cardFrame.minX, PaddrStyle.Inset.card, accuracy: 0.5)
        XCTAssertEqual(
            cardHost.bounds.maxX - cardFrame.maxX,
            PaddrStyle.Inset.card,
            accuracy: 0.5
        )
        XCTAssertEqual(cardFrame.minY, PaddrStyle.Inset.card, accuracy: 0.5)
        XCTAssertEqual(
            cardHost.bounds.maxY - cardFrame.maxY,
            PaddrStyle.Inset.card,
            accuracy: 0.5
        )

        let sectionView = PaddrSectionContainer {
            SettingsControlEdgeProbe(identifier: "section-content")
                .frame(maxWidth: .infinity)
                .frame(height: contentHeight)
        }
        .frame(width: width)
        let sectionHost = NSHostingView(rootView: sectionView)
        sectionHost.frame = NSRect(origin: .zero, size: sectionHost.fittingSize)
        sectionHost.layoutSubtreeIfNeeded()
        let sectionContent = try XCTUnwrap(
            descendants(of: NSView.self, in: sectionHost).first {
                $0.identifier?.rawValue == "section-content"
            }
        )
        let sectionFrame = sectionContent.convert(sectionContent.bounds, to: sectionHost)
        XCTAssertEqual(sectionHost.bounds.width, width, accuracy: 0.5)
        XCTAssertEqual(sectionHost.bounds.height, contentHeight, accuracy: 0.5)
        XCTAssertEqual(sectionFrame, sectionHost.bounds,
            "An inner functional group must not add another enclosing surface or margin")
    }

    func testSectionHeadingKeepsNaturalHeightOutsideTheControlRowFamily() {
        let hostingView = NSHostingView(rootView: PaddrSectionHeader("Pointer settings"))
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(hostingView.fittingSize.height, 0)
        XCTAssertLessThan(hostingView.fittingSize.height, PaddrStyle.Metrics.row)
    }

    func testCompactPickerRowsFitTheirInspectorColumn() {
        let rows = VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s3) {
            PaddrSettingsRow(title: "Layout") {
                Picker("Zone layout", selection: .constant(PadZoneLayout.fourCorners)) {
                    Text("Four corners").tag(PadZoneLayout.fourCorners)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: PaddrStyle.Width.controlMedium, alignment: .leading)
            }
            PaddrSettingsRow(title: "Action") {
                OutputBindingPicker(selection: .constant("Up arrow"))
            }
        }
        .environment(\.paddrStacksSettingLabels, true)
        .frame(width: PaddrStyle.minimumPadSectionWidth)
        let host = NSHostingView(rootView: rows)
        host.frame = NSRect(x: 0, y: 0, width: PaddrStyle.minimumPadSectionWidth,
            height: host.fittingSize.height)
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(host.fittingSize.width, PaddrStyle.minimumPadSectionWidth + 0.5)
        XCTAssertGreaterThan(host.fittingSize.height, 2 * PaddrStyle.Metrics.row,
            "Compact labels must sit above controls instead of competing for the same row")
        for control in descendants(of: NSControl.self, in: host) {
            let rect = control.convert(control.bounds, to: host)
            XCTAssertGreaterThanOrEqual(rect.minX, -0.5)
            XCTAssertLessThanOrEqual(rect.maxX, host.bounds.maxX + 0.5)
        }
    }

    /// The public `colorSchemeContrast`, `accessibilityReduceTransparency`, and
    /// `accessibilityDifferentiateWithoutColor` values are read-only, so the hosted matrix
    /// drives them through their underscore-prefixed writable key paths. `PaddrAppearance`'s
    /// own resolution of the same inputs is proved separately by
    /// `testPaddrAppearanceResolvesEveryAdaptiveCombination`.
    func testAdaptiveMatrixKeepsSurfacesFiniteAndControlsInsideTheHost() {
        for colorScheme in [ColorScheme.light, .dark] {
            for contrast in [ColorSchemeContrast.standard, .increased] {
                for reduceTransparency in [false, true] {
                    for differentiateWithoutColor in [false, true] {
                        let view = adaptiveMatrixSubject
                            .environment(\.colorScheme, colorScheme)
                            .environment(\._colorSchemeContrast, contrast)
                            .environment(\._accessibilityReduceTransparency, reduceTransparency)
                            .environment(
                                \._accessibilityDifferentiateWithoutColor,
                                differentiateWithoutColor
                            )

                        let label = """
                            \(colorScheme)/\(contrast)/\
                            reduceTransparency:\(reduceTransparency)/\
                            differentiateWithoutColor:\(differentiateWithoutColor)
                            """
                        let hostingView = NSHostingView(rootView: view)
                        let fitted = hostingView.fittingSize
                        XCTAssertTrue(fitted.width.isFinite, label)
                        XCTAssertTrue(fitted.height.isFinite, label)
                        XCTAssertGreaterThan(fitted.height, 0, label)

                        hostingView.frame = NSRect(
                            origin: .zero,
                            size: NSSize(width: PaddrStyle.padColumnWidth, height: fitted.height)
                        )
                        hostingView.layoutSubtreeIfNeeded()
                        for control in descendants(of: NSControl.self, in: hostingView) {
                            assertControlFits(control, in: hostingView)
                        }
                    }
                }
            }
        }
    }

    /// The three surfaces this slice moved onto `PaddrAppearance`: the card chrome, the
    /// status chip, and the permission row.
    private var adaptiveMatrixSubject: some View {
        VStack(spacing: PaddrStyle.Spacing.s3) {
            StatusDetailRow(
                title: LocalizedStringResource("Output"),
                value: LocalizedStringResource("Active"),
                systemImage: "wave.3.right.circle.fill",
                state: .active
            )
            PermissionTile(
                title: LocalizedStringResource("Accessibility"),
                detail: LocalizedStringResource("Sends mapped mouse, scroll, and keyboard input."),
                isGranted: false,
                requestAccessibilityLabel: "Request Accessibility",
                settingsAccessibilityLabel: "Open Accessibility Settings",
                requestAction: {},
                settingsAction: {}
            )
            PadConfigurationView(
                side: .left,
                configuration: .constant(PaddrConfiguration.default.left)
            )
        }
        .frame(width: PaddrStyle.padColumnWidth)
        .background { PanelBackgroundView() }
    }

    func testPadCardHeaderOmitsVisibleBehaviorHeadingAndSelectedSummary() async throws {
        let hostingView = NSHostingView(
            rootView: PadConfigurationView(
                side: .right,
                configuration: .constant(PadConfiguration(mode: .mouse))
            )
            .frame(width: PaddrStyle.padColumnWidth)
        )
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: PaddrStyle.padColumnWidth, height: 640)
        )
        await settle(hostingView)

        let renderedText = descendants(of: NSTextField.self, in: hostingView).map(\.stringValue)
        let selector = try XCTUnwrap(
            descendants(of: NSSegmentedControl.self, in: hostingView).first {
                $0.identifier?.rawValue == PaddrAccessibility.identifier("pad-mode", "right")
            }
        )

        XCTAssertFalse(
            renderedText.contains("Behavior"),
            "Behavior remains the control's accessibility label, not a redundant visible heading"
        )
        XCTAssertFalse(
            renderedText.contains("Pointer"),
            "The Behavior selector already communicates the selected mode"
        )
        XCTAssertEqual(selector.accessibilityLabel(), "Right trackpad behavior")
    }

    func testPointerSettingsFollowConfiguredWorkflowOrder() async throws {
        XCTAssertEqual(
            PointerSetting.allCases,
            [
                .sensitivity,
                .acceleration,
                .smoothing,
                .tapStabilization,
                .tapRadius,
                .tapAction,
                .pointerTracking,
            ]
        )
    }

    func testAdaptivePadHeaderMovesTheSameSelectorBelowTitleOnlyWhenNeeded() throws {
        let layout = PaddrAdaptiveHeaderLayout(
            spacing: PaddrStyle.Spacing.s2
        ) {
            SettingsControlEdgeProbe(identifier: "header-title")
                .frame(width: 120, height: 28)
            SettingsControlEdgeProbe(identifier: "header-selector")
                .frame(width: PaddrStyle.behaviorPickerWidth, height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        let hostingView = NSHostingView(rootView: layout)
        let defaultCardContentWidth = PaddrStyle.padColumnWidth
            - (2 * PaddrStyle.Inset.card)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: defaultCardContentWidth, height: 120)
        )
        hostingView.layoutSubtreeIfNeeded()

        let inlineTitle = try XCTUnwrap(
            descendants(of: NSView.self, in: hostingView).first {
                $0.identifier?.rawValue == "header-title"
            }
        )
        let inlineSelector = try XCTUnwrap(
            descendants(of: NSView.self, in: hostingView).first {
                $0.identifier?.rawValue == "header-selector"
            }
        )
        let inlineTitleFrame = inlineTitle.convert(inlineTitle.bounds, to: hostingView)
        let inlineSelectorFrame = inlineSelector.convert(inlineSelector.bounds, to: hostingView)

        XCTAssertEqual(inlineTitleFrame.midY, inlineSelectorFrame.midY, accuracy: 0.5)
        XCTAssertEqual(inlineTitleFrame.minX, hostingView.bounds.minX, accuracy: 0.5)
        XCTAssertEqual(inlineSelectorFrame.maxX, hostingView.bounds.maxX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(
            inlineSelectorFrame.minX - inlineTitleFrame.maxX,
            PaddrStyle.Spacing.s2,
            "The inline header should protect the declared title-to-control gap"
        )

        let constrainedWidth = 120 + PaddrStyle.Spacing.s2 + PaddrStyle.behaviorPickerWidth - 1
        hostingView.frame.size.width = constrainedWidth
        hostingView.layoutSubtreeIfNeeded()

        let stackedTitle = try XCTUnwrap(
            descendants(of: NSView.self, in: hostingView).first {
                $0.identifier?.rawValue == "header-title"
            }
        )
        let stackedSelector = try XCTUnwrap(
            descendants(of: NSView.self, in: hostingView).first {
                $0.identifier?.rawValue == "header-selector"
            }
        )
        let stackedTitleFrame = stackedTitle.convert(stackedTitle.bounds, to: hostingView)
        let stackedSelectorFrame = stackedSelector.convert(stackedSelector.bounds, to: hostingView)

        XCTAssertTrue(inlineTitle === stackedTitle)
        XCTAssertTrue(inlineSelector === stackedSelector)
        XCTAssertGreaterThanOrEqual(
            abs(stackedSelectorFrame.midY - stackedTitleFrame.midY),
            ((stackedSelectorFrame.height + stackedTitleFrame.height) / 2)
                + PaddrStyle.Spacing.s2 - 0.5,
            "The constrained header should stack without overlapping title and selector"
        )
        XCTAssertEqual(stackedSelectorFrame.minX, stackedTitleFrame.minX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(stackedSelectorFrame.minX, hostingView.bounds.minX - 0.5)
        XCTAssertLessThanOrEqual(stackedSelectorFrame.maxX, hostingView.bounds.maxX + 0.5)

        let rightToLeftLayout = PaddrAdaptiveHeaderLayout(
            spacing: PaddrStyle.Spacing.s2
        ) {
            SettingsControlEdgeProbe(identifier: "rtl-header-title")
                .frame(width: 120, height: 28)
            SettingsControlEdgeProbe(identifier: "rtl-header-selector")
                .frame(width: PaddrStyle.behaviorPickerWidth, height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
        let rightToLeftHost = NSHostingView(rootView: rightToLeftLayout)
        rightToLeftHost.frame = NSRect(
            origin: .zero,
            size: NSSize(width: defaultCardContentWidth, height: 120)
        )
        rightToLeftHost.layoutSubtreeIfNeeded()

        let rightToLeftTitle = try XCTUnwrap(
            descendants(of: NSView.self, in: rightToLeftHost).first {
                $0.identifier?.rawValue == "rtl-header-title"
            }
        )
        let rightToLeftSelector = try XCTUnwrap(
            descendants(of: NSView.self, in: rightToLeftHost).first {
                $0.identifier?.rawValue == "rtl-header-selector"
            }
        )
        let rightToLeftTitleFrame = rightToLeftTitle.convert(
            rightToLeftTitle.bounds,
            to: rightToLeftHost
        )
        let rightToLeftSelectorFrame = rightToLeftSelector.convert(
            rightToLeftSelector.bounds,
            to: rightToLeftHost
        )

        XCTAssertEqual(rightToLeftTitleFrame.midY, rightToLeftSelectorFrame.midY, accuracy: 0.5)
        XCTAssertEqual(rightToLeftTitleFrame.maxX, rightToLeftHost.bounds.maxX, accuracy: 0.5)
        XCTAssertEqual(rightToLeftSelectorFrame.minX, rightToLeftHost.bounds.minX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(
            rightToLeftTitleFrame.minX - rightToLeftSelectorFrame.maxX,
            PaddrStyle.Spacing.s2,
            "The RTL inline header should protect the declared title-to-control gap"
        )
        XCTAssertGreaterThanOrEqual(
            rightToLeftSelectorFrame.minX,
            rightToLeftHost.bounds.minX - 0.5
        )
        XCTAssertLessThanOrEqual(
            rightToLeftTitleFrame.maxX,
            rightToLeftHost.bounds.maxX + 0.5
        )
    }

    func testPointerTrackingToggleReflectsDefaultsAndLegacyBindingAtRadiusZero() async throws {
        let defaultView = PadConfigurationView(
            side: .right,
            configuration: .constant(PadConfiguration(mode: .mouse)),
            initialTuningExpanded: true
        )
        .frame(width: PaddrStyle.Metrics.minimumWindowSize.width - (2 * PaddrStyle.Spacing.s4))
        let defaultHostingView = NSHostingView(rootView: defaultView)
        defaultHostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: PaddrStyle.Metrics.minimumWindowSize.width - (2 * PaddrStyle.Spacing.s4),
                height: 640
            )
        )
        await settle(defaultHostingView)

        let defaultSwitches = descendants(of: PaddrTuningSwitchButton.self, in: defaultHostingView)
        XCTAssertEqual(defaultSwitches.count, 4)
        let defaultToggle = try XCTUnwrap(defaultSwitches.last)
        XCTAssertEqual(defaultToggle.state, .on)
        XCTAssertEqual(defaultToggle.accessibilityRole(), .checkBox)
        XCTAssertEqual(accessibilityIntegerValue(of: defaultToggle), 1)
        XCTAssertTrue(defaultToggle.isEnabled)
        let defaultControls = descendants(of: NSControl.self, in: defaultHostingView)
        XCTAssertGreaterThanOrEqual(defaultControls.count, 2)
        for control in defaultControls {
            assertControlFits(control, in: defaultHostingView)
        }

        var legacy = try JSONDecoder().decode(
            PadConfiguration.self,
            from: Data("{\"mode\":\"mouse\",\"mouseDeadzone\":0}".utf8)
        )
        let legacyBinding = Binding(
            get: { legacy },
            set: { legacy = $0 }
        )
        let legacyView = PadConfigurationView(
            side: .right,
            configuration: legacyBinding,
            initialTuningExpanded: true
        )
        .frame(width: PaddrStyle.padColumnWidth)
        let legacyHostingView = NSHostingView(rootView: legacyView)
        legacyHostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: PaddrStyle.padColumnWidth,
                height: PaddrStyle.Metrics.defaultWindowSize.height
            )
        )
        await settle(legacyHostingView)

        let legacySwitches = descendants(of: PaddrTuningSwitchButton.self, in: legacyHostingView)
        XCTAssertEqual(legacySwitches.count, 4)
        let legacyToggle = try XCTUnwrap(legacySwitches.last)
        XCTAssertEqual(legacy.centerTapTrackingMode, .coupled)
        XCTAssertEqual(legacyToggle.state, .off)
        XCTAssertEqual(legacyToggle.accessibilityRole(), .checkBox)
        XCTAssertEqual(accessibilityIntegerValue(of: legacyToggle), 0)
        XCTAssertTrue(legacyToggle.isEnabled)
        legacyToggle.performClick(nil)
        await settle(legacyHostingView)
        XCTAssertEqual(legacy.centerTapTrackingMode, .decoupled)
        XCTAssertEqual(legacyToggle.state, .on)
        XCTAssertEqual(accessibilityIntegerValue(of: legacyToggle), 1)
        assertControlFits(legacyToggle, in: legacyHostingView)
    }

    func testAccelerationSwitchRetainsStrengthAndKeepsPadsIndependent() async throws {
        var configuration = PaddrConfiguration.default
        configuration.left = PadConfiguration(mode: .mouse, mouseAcceleration: 0.65)
        configuration.right = PadConfiguration(mode: .mouse, mouseAcceleration: 0.2)
        let originalRight = configuration.right
        let host = NSHostingView(rootView: PadConfigurationView(side: .left,
            configuration: Binding(get: { configuration.left }, set: { configuration.left = $0 }),
            initialTuningExpanded: true))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 800)
        await settle(host)
        let toggle = try XCTUnwrap(descendants(of: PaddrTuningSwitchButton.self, in: host).first)
        XCTAssertEqual(toggle.state, .on)
        toggle.performClick(nil)
        await settle(host)
        XCTAssertFalse(configuration.left.mouseAccelerationEnabled)
        XCTAssertEqual(configuration.left.mouseAcceleration, 0.65)
        XCTAssertFalse(PointerTuningPresentation.summary(configuration: configuration.left).contains("Acceleration"))
        toggle.performClick(nil)
        await settle(host)
        XCTAssertTrue(configuration.left.mouseAccelerationEnabled)
        XCTAssertEqual(configuration.left.mouseAcceleration, 0.65)
        XCTAssertEqual(configuration.right, originalRight)
    }

    func testPointerStabilityControlsExposePerPadDefaultsAndBindings() async throws {
        var configuration = PadConfiguration(mode: .mouse)
        let view = PadConfigurationView(
            side: .right,
            configuration: Binding(
                get: { configuration },
                set: { configuration = $0 }
            ),
            initialTuningExpanded: true
        )
        .frame(width: PaddrStyle.padColumnWidth)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: PaddrStyle.padColumnWidth,
                height: PaddrStyle.Metrics.defaultWindowSize.height
            )
        )
        await settle(hostingView)

        let switches = descendants(of: PaddrTuningSwitchButton.self, in: hostingView)
        XCTAssertEqual(switches.count, 4)
        let smoothing = try XCTUnwrap(switches.dropFirst().first)
        let stabilization = try XCTUnwrap(switches.dropFirst(2).first)

        XCTAssertEqual(smoothing.state, .off)
        XCTAssertEqual(stabilization.state, .on)

        smoothing.performClick(nil)
        stabilization.performClick(nil)
        await settle(hostingView)

        XCTAssertTrue(configuration.pointerSmoothingEnabled)
        XCTAssertFalse(configuration.tapStabilizationEnabled)
    }

    func testPointerTuningStartsCollapsedAndRemainsInspectableInReadOnlyProfiles() async throws {
        var configuration = PadConfiguration(mode: .mouse)
        let binding = Binding(get: { configuration }, set: { configuration = $0 })
        let collapsed = NSHostingView(rootView: PadConfigurationView(
            side: .right, configuration: binding, isEditable: false
        ))
        collapsed.frame = NSRect(x: 0, y: 0, width: 640, height: 1000)
        await settle(collapsed)
        XCTAssertTrue(descendants(of: PaddrTuningSwitchButton.self, in: collapsed).isEmpty,
            "Advanced switches should not compete with sensitivity and touch tap in the initial view")

        let expanded = NSHostingView(rootView: PadConfigurationView(
            side: .right, configuration: binding, isEditable: false, initialTuningExpanded: true
        ))
        expanded.frame = NSRect(x: 0, y: 0, width: 640, height: 1000)
        await settle(expanded)
        let switches = descendants(of: PaddrTuningSwitchButton.self, in: expanded)
        XCTAssertEqual(switches.count, 4, "Read-only tuning must remain available for inspection")
        XCTAssertTrue(switches.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(configuration, PadConfiguration(mode: .mouse))
        XCTAssertGreaterThan(expanded.fittingSize.height, collapsed.fittingSize.height)
    }

    func testPointerTuningSummaryIncludesOnlyEnabledEffectiveSettings() {
        var configuration = PadConfiguration(mode: .mouse)
        configuration.mouseAcceleration = 0
        configuration.pointerSmoothingEnabled = false
        configuration.tapStabilizationEnabled = false
        configuration.mouseDeadzone = 0
        configuration.centerTapTrackingMode = .coupled
        let locale = Locale(identifier: "en")
        XCTAssertEqual(PointerTuningPresentation.summary(configuration: configuration, locale: locale),
            "No additional tuning enabled")

        configuration.pointerSmoothingEnabled = true
        configuration.pointerSmoothingStrength = 0.35
        configuration.tapStabilizationEnabled = true
        configuration.tapStabilizationThresholdPoints = 6
        configuration.mouseDeadzone = 0.2
        let summary = PointerTuningPresentation.summary(configuration: configuration, locale: locale)
        XCTAssertTrue(summary.contains("Smoothing 35%"))
        XCTAssertTrue(summary.contains("Tap stabilization 6 pt"))
        XCTAssertTrue(summary.contains("Tap radius 20%"))
        XCTAssertTrue(summary.contains("Pointer dead zone"))
        XCTAssertFalse(summary.contains("Acceleration"))

        configuration.pointerSmoothingEnabled = false
        configuration.centerTapTrackingMode = .decoupled
        let updated = PointerTuningPresentation.summary(configuration: configuration, locale: locale)
        XCTAssertFalse(updated.contains("Smoothing"), "A stored strength must not imply disabled smoothing is active")
        XCTAssertFalse(updated.contains("Pointer dead zone"), "Decoupled tracking must not be described as a dead zone")
    }

    func testTapStabilizationUsesCompleteLocalizedToleranceForSliderAccessibilityValue() {
        let valueText = TapStabilizationPresentation.toleranceValue(
            points: 6,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(valueText, "6 pt")
        let row = ToggleValueSliderRow(
            title: "Tap stabilization",
            isEnabled: .constant(true),
            value: .constant(6),
            range: ConfigurationLimits.tapStabilizationThresholdPoints,
            step: 1,
            valueText: valueText,
            accessibilityIdentifier: "tap-stabilization-test",
            sliderAccessibilityLabel: "Tap Stabilization Tolerance"
        )
        XCTAssertEqual(row.sliderAccessibilityValue, valueText)
        XCTAssertEqual(row.sliderAccessibilityLabelText, "Tap Stabilization Tolerance")
    }

    func testPermissionActionsExposeUniqueVoiceControlNames() {
        let input = PermissionTile(
            title: "Input Monitoring",
            detail: "Receives Steam Controller 2 reports from the puck.",
            isGranted: false,
            identifier: "input-monitoring",
            requestAccessibilityLabel: "Request Input Monitoring",
            settingsAccessibilityLabel: "Open Input Monitoring Settings",
            requestAction: {},
            settingsAction: {}
        )
        let accessibility = PermissionTile(
            title: "Accessibility",
            detail: "Sends mapped mouse, scroll, and keyboard input.",
            isGranted: false,
            identifier: "accessibility",
            requestAccessibilityLabel: "Request Accessibility",
            settingsAccessibilityLabel: "Open Accessibility Settings",
            requestAction: {},
            settingsAction: {}
        )

        XCTAssertEqual(String(localized: input.requestAccessibilityLabel), "Request Input Monitoring")
        XCTAssertEqual(String(localized: input.settingsAccessibilityLabel), "Open Input Monitoring Settings")
        XCTAssertEqual(String(localized: accessibility.requestAccessibilityLabel), "Request Accessibility")
        XCTAssertEqual(String(localized: accessibility.settingsAccessibilityLabel), "Open Accessibility Settings")
    }

    func testUnsavedQuitAlertUsesThreeExplicitActions() {
        let alert = PaddrUnsavedQuitAlert.make(profileName: "Editing")

        XCTAssertEqual(alert.messageText, "Save changes before quitting?")
        XCTAssertEqual(
            alert.informativeText,
            "Changes to “Editing” will be lost if you quit without saving."
        )
        XCTAssertEqual(alert.buttons.map(\.title), [
            "Save & Quit",
            "Cancel",
            "Quit Without Saving"
        ])
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "\u{1b}")
        XCTAssertTrue(alert.buttons[2].hasDestructiveAction)
        XCTAssertEqual(
            PaddrUnsavedQuitAlert.action(for: .alertFirstButtonReturn),
            .saveAndQuit
        )
        XCTAssertEqual(
            PaddrUnsavedQuitAlert.action(for: .alertSecondButtonReturn),
            .cancel
        )
        XCTAssertEqual(
            PaddrUnsavedQuitAlert.action(for: .alertThirdButtonReturn),
            .quitWithoutSaving
        )
    }

    func testProfilePickerPresentsPendingCreatedProfile() async throws {
        try await assertPendingProfilePicker(
            expectedName: "Third",
            operation: { $0.createProfile(named: "Third") }
        )
    }

    func testProfilePickerPresentsPendingDuplicatedProfile() async throws {
        try await assertPendingProfilePicker(
            expectedName: "Default Copy",
            operation: { $0.duplicateActiveProfile() }
        )
    }

    func testOutputSummaryFitsMinimumWindowWidthWithUnavailableBattery() async throws {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        XCTAssertNil(model.receiverDescription)
        XCTAssertFalse(model.controllerConnected)
        XCTAssertNil(model.batteryStatus)

        assertApplyBarFitsMinimumWindow(model: model)
    }

    func testPointerTuningLabelClickExpandsAndCollapsesWithoutEditing() async throws {
        var configuration = PaddrConfiguration.default.right
        var writes = 0
        let host = NSHostingView(rootView: PadConfigurationView(
            side: .right,
            configuration: Binding(get: { configuration }, set: { configuration = $0; writes += 1 }),
            isEditable: false
        ).environment(\.accessibilityEnabled, true).padding(20))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 480, height: 750),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        await settle(host)
        for expanded in [true, false] {
            let disclosure = try XCTUnwrap(accessibilityElement(in: host,
                identifier: "paddr.pad.right.pointer-tuning"))
            let frame = try XCTUnwrap(disclosure.accessibilityFrame?())
            // Click the text well beyond the disclosure indicator, not its arrow.
            let location = window.convertPoint(fromScreen: CGPoint(x: frame.minX + 70, y: frame.maxY - 8))
            let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime + 0.1,
                windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
            window.sendEvent(down)
            window.sendEvent(up)
            await settle(host)
            XCTAssertEqual(!descendants(of: PaddrTuningSwitchButton.self, in: host).isEmpty, expanded)
            XCTAssertEqual(writes, 0, "Read-only tuning remains inspectable without changing mappings")
        }
    }

    func testFooterOmitsRedundantControllerAdviceButRetainsActionableMessages() async throws {
        let store = BlockingProfileStore()
        let session = PresentationSession()
        let model = PaddrMenuModel(dependencies: dependencies(
            store: store, session: session, receiver: "Fake receiver"
        ))
        defer { store.releaseSave() }
        let started = await waitUntil { await session.startCount == 1 }
        XCTAssertTrue(started)
        for enabled in [false, true] {
            model.isEnabled = enabled
            XCTAssertEqual(model.readiness.nextAction, .connectController)
            XCTAssertFalse(ApplyBarView(model: model).showsStatusMessage)
            let host = NSHostingView(rootView: ApplyBarView(model: model)
                .environment(\.accessibilityEnabled, true))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 996, height: 250),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            await settle(host)
            XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.status.next-action"))
            let connection = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.status.details"))
            let value = (connection as? NSObject)?.perform(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? String
            XCTAssertEqual(value, "Controller not connected")
            window.close()
        }
        await session.send(.failed("Fixture output failure"))
        let failed = await waitUntil { model.status.messageState == .failure }
        XCTAssertTrue(failed)
        XCTAssertTrue(ApplyBarView(model: model).showsStatusMessage,
            "Suppressing repeated connection advice must preserve immediate failures")
        _ = await session.stop()
    }

    func testFooterPublishesBatteryWithoutOpeningConnectionDetails() async throws {
        let store = BlockingProfileStore()
        let session = PresentationSession()
        let model = PaddrMenuModel(dependencies: dependencies(
            store: store, session: session, receiver: "Fake receiver"
        ))
        defer { store.releaseSave() }
        let started = await waitUntil { await session.startCount == 1 }
        XCTAssertTrue(started)
        await session.send(.controllerConnected)
        let connected = await waitUntil { model.controllerConnected }
        XCTAssertTrue(connected)
        let host = NSHostingView(rootView: ApplyBarView(model: model)
            .environment(\.accessibilityEnabled, true))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 996, height: 250),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        await settle(host)
        let pendingBattery = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.status.battery"))
        let pendingValue = (pendingBattery as? NSObject)?.perform(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? String
        XCTAssertEqual(pendingValue, BatteryStatusPresentation(status: nil).accessibilityValue)

        for percentage: UInt8 in [100, 75] {
            await session.send(.batteryUpdated(.init(chargeState: .chargingDone, percentage: percentage)))
            let updated = await waitUntil { model.batteryStatus?.percentage == percentage }
            XCTAssertTrue(updated)
            await settle(host)
            let battery = try XCTUnwrap(accessibilityElement(in: host, identifier: "paddr.status.battery"))
            let value = (battery as? NSObject)?.perform(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? String
            XCTAssertEqual(value, BatteryStatusPresentation(status: model.batteryStatus).accessibilityValue)
        }
        await session.send(.controllerLost(.init(reportCount: 0, actionCount: 0)))
        let lost = await waitUntil { !model.controllerConnected }
        XCTAssertTrue(lost)
        await settle(host)
        XCTAssertNil(accessibilityElement(in: host, identifier: "paddr.status.battery"))
        _ = await session.stop()
    }

    private func accessibilityElement(in view: NSView, identifier: String) -> AnyObject? {
        var visited = Set<ObjectIdentifier>()
        func find(_ object: AnyObject) -> AnyObject? {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return nil }
            if object.accessibilityIdentifier?() == identifier { return object }
            for child in object.accessibilityChildren?() as? [Any] ?? [] {
                if let result = find(child as AnyObject) { return result }
            }
            return nil
        }
        return find(view)
    }

    /// SwiftUI reports some names as attributed strings, and static text as a value.
    private func accessibilityText(_ object: AnyObject, _ attribute: String) -> String? {
        guard let object = object as? NSObject else { return nil }
        let selector = NSSelectorFromString(attribute)
        guard object.responds(to: selector) else { return nil }
        let value = object.perform(selector)?.takeUnretainedValue()
        return (value as? NSAttributedString)?.string ?? value as? String
    }

    private func accessibilityElements(in view: NSView, identifier: String) -> [AnyObject] {
        var visited = Set<ObjectIdentifier>()
        var matches: [AnyObject] = []
        func collect(_ object: AnyObject) {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return }
            if object.accessibilityIdentifier?() == identifier { matches.append(object) }
            for child in object.accessibilityChildren?() as? [Any] ?? [] { collect(child as AnyObject) }
        }
        collect(view)
        return matches
    }

    private func accessibilityElements(in view: NSView, where matches: (String) -> Bool) -> [AnyObject] {
        var visited = Set<ObjectIdentifier>()
        var found: [AnyObject] = []
        func collect(_ object: AnyObject) {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return }
            if let identifier = object.accessibilityIdentifier?(), matches(identifier) { found.append(object) }
            for child in object.accessibilityChildren?() as? [Any] ?? [] { collect(child as AnyObject) }
        }
        collect(view)
        return found
    }

    /// Every label and static-text value in the tree.
    private func accessibilityTexts(in view: NSView) -> [String] {
        var visited = Set<ObjectIdentifier>()
        var texts: [String] = []
        func collect(_ object: AnyObject) {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return }
            for attribute in ["accessibilityLabel", "accessibilityValue"] {
                if let text = accessibilityText(object, attribute), !text.isEmpty { texts.append(text) }
            }
            for child in object.accessibilityChildren?() as? [Any] ?? [] { collect(child as AnyObject) }
        }
        collect(view)
        return texts
    }

    /// Toolbar items and window state update a run-loop turn after the content.
    private func settle(_ window: NSWindow) async {
        for _ in 0..<8 {
            window.contentView?.layoutSubtreeIfNeeded()
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testOutputSummaryFitsMinimumWindowWidthWithLongestBatteryValue() async throws {
        let store = BlockingProfileStore()
        let session = PresentationSession()
        let model = PaddrMenuModel(
            dependencies: dependencies(
                store: store,
                session: session,
                receiver: "Fake receiver"
            )
        )
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        let didStart = await waitUntil { await session.startCount == 1 }
        XCTAssertTrue(didStart)
        await session.send(.controllerConnected)
        await session.send(.batteryUpdated(.init(chargeState: .chargingDone, percentage: 100)))
        let didPublishBattery = await waitUntil { model.batteryStatus?.percentage == 100 }
        XCTAssertTrue(didPublishBattery)

        assertApplyBarFitsMinimumWindow(model: model)
        _ = await session.stop()
    }

    func testEnablingDuringSaveShowsPersistenceGuidanceUntilSaveCompletesOrFails() async throws {
        for failsSave in [false, true] {
            var document = ConfigurationProfileDocument.default
            let profile = try document.createProfile(named: "Editable")
            try document.activateProfile(id: profile.id)
            let loadedDocument = document
            let store = BlockingProfileStore(failsSave: failsSave)
            defer { store.releaseSave() }
            let session = PresentationSession()
            let model = PaddrMenuModel(dependencies: MenuDependencies(
                session: session,
                loadProfiles: { ConfigurationProfileLoadResult(document: loadedDocument) },
                saveProfiles: store.save,
                probeReceiver: { "Fake receiver" },
                accessibilityTrusted: { _ in true },
                inputMonitoringAccess: { _ in .granted },
                openPrivacySettings: { _ in },
                sleep: { duration in try await Task.sleep(for: duration) },
                reconnectDelay: { _ in throw CancellationError() }
            ))
            let initialized = await waitUntil { model.isInitialized }
            XCTAssertTrue(initialized)
            let started = await waitUntil { await session.startCount == 1 }
            XCTAssertTrue(started)
            await session.send(.controllerConnected)
            let connected = await waitUntil { model.controllerConnected }
            XCTAssertTrue(connected)
            let host = NSHostingView(rootView: ApplyBarView(model: model)
                .environment(\.accessibilityEnabled, true))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 300),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            await settle(host)

            model.configuration.left.sensitivity = 3
            model.saveAndApply()
            let saving = await waitUntil { store.didStartSave }
            XCTAssertTrue(saving)
            XCTAssertTrue(model.canToggleOutput)
            model.isEnabled = true
            XCTAssertEqual(model.status, .off)
            XCTAssertEqual(model.readiness.nextAction, .waitForProfileOperation,
                "Pending persistence is not a neutral-input wait")
            await settle(host)
            XCTAssertNil(footerNextAction(in: host), "Brief preparation should not flash guidance")
            try await Task.sleep(for: .milliseconds(300))
            await settle(host)
            XCTAssertEqual(footerNextAction(in: host),
                String(localized: PaddrReadinessNextAction.waitForProfileOperation.title))
            XCTAssertFalse(model.isRunning)
            let startsBeforeSave = await session.startCount
            XCTAssertEqual(startsBeforeSave, 1, "Activation cannot restart before persistence finishes")
            let enabledBeforeSave = await session.startedWithOutputEnabled
            XCTAssertFalse(enabledBeforeSave.contains(true))

            store.releaseSave()
            if failsSave {
                let failed = await waitUntil { !model.isEnabled && model.status.messageState == .failure }
                XCTAssertTrue(failed)
                XCTAssertTrue(ApplyBarView(model: model).showsStatusMessage)
                XCTAssertTrue(model.hasUnsavedChanges)
                let enabledAfterFailure = await session.startedWithOutputEnabled
                XCTAssertFalse(enabledAfterFailure.contains(true))
            } else {
                let restarted = await waitUntil { await session.startCount == 2 }
                XCTAssertTrue(restarted)
                XCTAssertEqual(model.savedConfiguration.left.sensitivity, 3)
                let startedSensitivity = await session.lastConfiguration?.left.sensitivity
                XCTAssertEqual(startedSensitivity, 3)
                await session.send(.controllerConnected)
                let waiting = await waitUntil { model.status == .waitingForNeutral }
                XCTAssertTrue(waiting)
                await settle(host)
                XCTAssertNil(footerNextAction(in: host), "Neutral guidance needs its own fresh delay")
                try await Task.sleep(for: .milliseconds(300))
                await settle(host)
                XCTAssertEqual(footerNextAction(in: host),
                    String(localized: PaddrReadinessNextAction.releaseTrackpads.title))
                await session.send(.outputArmed)
                let active = await waitUntil { model.isRunning }
                XCTAssertTrue(active)
                await settle(host)
                XCTAssertNil(footerNextAction(in: host))
            }
            _ = await session.stop()
        }
    }

    func testProfileWorkAlongsideEnabledSessionDoesNotReplaceNeutralGuidance() async throws {
        // Both metadata writes and saving a new draft can run beside the current
        // enabled session. Neither prevents that session from observing neutral input.
        for renamesProfile in [true, false] {
            var document = ConfigurationProfileDocument.default
            let profile = try document.createProfile(named: "Editable")
            try document.activateProfile(id: profile.id)
            let loadedDocument = document
            let store = BlockingProfileStore()
            defer { store.releaseSave() }
            let session = PresentationSession()
            let model = PaddrMenuModel(dependencies: MenuDependencies(
                session: session,
                loadProfiles: { ConfigurationProfileLoadResult(document: loadedDocument) },
                saveProfiles: store.save,
                probeReceiver: { "Fake receiver" },
                accessibilityTrusted: { _ in true },
                inputMonitoringAccess: { _ in .granted },
                openPrivacySettings: { _ in },
                sleep: { duration in try await Task.sleep(for: duration) },
                reconnectDelay: { _ in throw CancellationError() }
            ))
            let initialized = await waitUntil { model.isInitialized }
            XCTAssertTrue(initialized)
            let started = await waitUntil { await session.startCount == 1 }
            XCTAssertTrue(started)
            await session.send(.controllerConnected)
            let connected = await waitUntil { model.controllerConnected }
            XCTAssertTrue(connected)
            let host = NSHostingView(rootView: ApplyBarView(model: model)
                .environment(\.accessibilityEnabled, true))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 300),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            model.isEnabled = true
            let waiting = await waitUntil { model.status == .waitingForNeutral }
            XCTAssertTrue(waiting)
            try await Task.sleep(for: .milliseconds(300))
            await settle(host)
            let neutralInstruction = String(localized: PaddrReadinessNextAction.releaseTrackpads.title)
            XCTAssertEqual(footerNextAction(in: host), neutralInstruction)

            if renamesProfile {
                XCTAssertTrue(model.renameActiveProfile(to: "Renamed"))
            } else {
                model.configuration.left.sensitivity = 3
                model.saveAndApply()
            }
            let saving = await waitUntil { store.didStartSave }
            XCTAssertTrue(saving)
            XCTAssertEqual(model.readiness.nextAction, .releaseTrackpads)
            await settle(host)
            XCTAssertEqual(footerNextAction(in: host), neutralInstruction)
            try await Task.sleep(for: .milliseconds(300))
            await settle(host)
            XCTAssertEqual(footerNextAction(in: host), neutralInstruction,
                "Unrelated persistence must not replace the actionable neutral instruction")

            await session.send(.outputArmed)
            let activeBeforeSave = await waitUntil { model.isRunning }
            XCTAssertTrue(activeBeforeSave, "The existing session may activate before this save completes")
            XCTAssertFalse(model.canManageProfiles, "The save must still be pending when output arms")
            await settle(host)
            XCTAssertNil(footerNextAction(in: host))
            store.releaseSave()
            let saved = await waitUntil { model.canManageProfiles }
            XCTAssertTrue(saved)
            if renamesProfile {
                XCTAssertEqual(model.activeProfile.name, "Renamed")
                let starts = await session.startCount
                XCTAssertEqual(starts, 1, "A rename must not restart the session")
            } else {
                let restarted = await waitUntil { await session.startCount == 2 }
                XCTAssertTrue(restarted)
                XCTAssertEqual(model.savedConfiguration.left.sensitivity, 3)
            }
            _ = await session.stop()
        }
    }

    private func footerNextAction(in view: NSView) -> String? {
        var visited = Set<ObjectIdentifier>()
        func find(_ object: AnyObject) -> String? {
            guard visited.insert(ObjectIdentifier(object)).inserted else { return nil }
            if object.accessibilityIdentifier?() == "paddr.status.next-action" {
                return object.accessibilityLabel?()
            }
            let children = object.accessibilityChildren?() as? [Any] ?? []
            for child in children {
                if let label = find(child as AnyObject) { return label }
            }
            return nil
        }
        return find(view)
    }

    func testOutputTransitionGuidanceAvoidsBriefFlashesButShowsPersistentWaitsAndErrors() async throws {
        for armsQuickly in [true, false] {
            let store = BlockingProfileStore()
            let session = PresentationSession()
            let model = PaddrMenuModel(dependencies: dependencies(
                store: store, session: session, receiver: "Fake receiver"
            ))
            defer { store.releaseSave() }
            let initialized = await waitUntil { model.isInitialized }
            XCTAssertTrue(initialized)
            let started = await waitUntil { await session.startCount == 1 }
            XCTAssertTrue(started)
            await session.send(.controllerConnected)
            let connected = await waitUntil { model.controllerConnected }
            XCTAssertTrue(connected)
            let host = NSHostingView(rootView: ApplyBarView(model: model))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 300),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            await settle(host)
            let idleHeight = host.fittingSize.height

            model.isEnabled = true
            XCTAssertEqual(model.status, .waitingForNeutral)
            await settle(host)
            XCTAssertEqual(host.fittingSize.height, idleHeight, accuracy: 1,
                "A normal activation wait must not insert a flashing footer row")
            if !armsQuickly {
                let guidanceAppeared = await waitUntil {
                    await self.settle(host)
                    return host.fittingSize.height > idleHeight + 5
                }
                XCTAssertTrue(guidanceAppeared, "A sustained neutral wait must still explain how to activate")
            }
            await session.send(.outputArmed)
            let active = await waitUntil { model.isRunning }
            XCTAssertTrue(active)
            await settle(host)
            XCTAssertEqual(host.fittingSize.height, idleHeight, accuracy: 1)
            // A canceled delayed task must not resurrect guidance after output activates.
            try await Task.sleep(for: .milliseconds(300))
            await settle(host)
            XCTAssertEqual(host.fittingSize.height, idleHeight, accuracy: 1)

            model.isEnabled = false
            XCTAssertTrue(model.isReleasingOutput)
            XCTAssertFalse(model.canToggleOutput, "Release safety gating must remain immediate")
            XCTAssertEqual(ApplyBarView(model: model).outputValue, LocalizedStringResource("Releasing"))
            await settle(host)
            XCTAssertEqual(host.fittingSize.height, idleHeight, accuracy: 1,
                "A normal output release must not insert a flashing footer row")
            if !armsQuickly {
                let releaseGuidanceAppeared = await waitUntil {
                    await self.settle(host)
                    return host.fittingSize.height > idleHeight + 5
                }
                XCTAssertTrue(releaseGuidanceAppeared, "A sustained release must still explain the wait")
            }
            await session.send(.outputReleased(revision: .max))
            let released = await waitUntil { !model.isReleasingOutput }
            XCTAssertTrue(released)
            XCTAssertTrue(model.canToggleOutput)
            await settle(host)
            XCTAssertEqual(host.fittingSize.height, idleHeight, accuracy: 1)
            try await Task.sleep(for: .milliseconds(300))
            await settle(host)
            XCTAssertEqual(host.fittingSize.height, idleHeight, accuracy: 1,
                "Canceled guidance must not appear after releases complete")

            await session.send(.failed("Fixture output failure"))
            let failed = await waitUntil { model.status.messageState == .failure }
            XCTAssertTrue(failed)
            XCTAssertTrue(ApplyBarView(model: model).showsStatusMessage,
                "Failure guidance must not be gated by the neutral-wait delay")
            await settle(host)
            XCTAssertGreaterThan(host.fittingSize.height, idleHeight + 5)
            _ = await session.stop()
        }
    }

    func testBottomStatusBarOwnsTrailingOutputToggleWithPreservedSemantics() async throws {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }
        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)

        let applyBar = ApplyBarView(model: model)
        let hostingView = NSHostingView(rootView: applyBar)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: PaddrStyle.Metrics.defaultWindowSize.width,
                height: PaddrStyle.Control.height
            )
        )
        await settle(hostingView)
        hostingView.frame.size.height = hostingView.fittingSize.height
        await settle(hostingView)

        let switches = descendants(of: PaddrTuningSwitchButton.self, in: hostingView)
            .filter { $0.accessibilityIdentifier() == "paddr.toolbar.output" }
        let outputToggle = try XCTUnwrap(switches.first)
        XCTAssertEqual(switches.count, 1)
        XCTAssertEqual(
            applyBar.outputToggleAccessibilityIdentifier,
            PaddrAccessibility.identifier("toolbar", "output")
        )
        XCTAssertEqual(
            String(localized: applyBar.outputToggleAccessibilityLabel),
            "Enable output"
        )
        XCTAssertEqual(String(localized: applyBar.outputToggleAccessibilityValue), "Off")
        XCTAssertEqual(
            String(localized: applyBar.outputToggleHelp),
            "Enable or disable output"
        )
        XCTAssertEqual(outputToggle.accessibilitySubrole(), .switch)
        XCTAssertEqual(outputToggle.accessibilityLabel(), "Enable output")
        XCTAssertEqual(outputToggle.accessibilityHelp(), String(localized: applyBar.outputToggleHelp))
        XCTAssertEqual(outputToggle.bounds.size, NSSize(width: PaddrStyle.Width.toggle, height: PaddrStyle.Control.height))
        XCTAssertNil(outputToggle.accessibilityChildren(), "The output switch has one binary accessibility target")
        XCTAssertEqual(accessibilityIntegerValue(of: outputToggle), 0)
        XCTAssertEqual(outputToggle.isEnabled, model.canToggleOutput)
        XCTAssertEqual(
            outputToggle.convert(outputToggle.trackRect, to: hostingView).maxX,
            hostingView.bounds.maxX - PaddrStyle.Inset.window,
            accuracy: 1,
            "The drawn track ends on the workspace's trailing edge, inside the floating bar"
        )
        XCTAssertEqual(PaddrStyle.Bar.margin + PaddrStyle.Bar.inset, PaddrStyle.Inset.window)

        outputToggle.performClick(nil)
        await settle(hostingView)

        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(accessibilityIntegerValue(of: outputToggle), 1)
        XCTAssertEqual(
            String(localized: ApplyBarView(model: model).outputToggleAccessibilityValue),
            "On"
        )
        XCTAssertGreaterThanOrEqual(hostingView.fittingSize.height, PaddrStyle.Metrics.row)
    }

    func testStatusDetailRowIsPlainTextThatRetainsAccessibleIdentityAndValue() {
        let row = StatusDetailRow(
            title: "Access",
            value: LocalizedStringResource("Needed"),
            systemImage: "exclamationmark.shield",
            state: .problem,
            identifier: "access"
        )
        let host = NSHostingView(rootView: row)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()

        XCTAssertLessThan(host.fittingSize.height, PaddrStyle.Control.height,
            "A read-only value is a line of text, not a control-height container")
        XCTAssertEqual(row.accessibilityLabelText, "Access")
        XCTAssertEqual(row.accessibilityValueText, "Needed")
    }

    func testBatteryDetailShowsItsPercentageAndSpeaksTheFullState() {
        let battery = StatusDetailRow(
            title: "Battery",
            value: String("60%"),
            systemImage: "battery.50percent",
            state: .ready,
            accessibilityValue: "Level 60%, Discharging"
        )
        let shorter = NSHostingView(rootView: StatusDetailRow(
            title: "Battery", value: String("6%"), systemImage: "battery.0percent", state: .critical))
        let host = NSHostingView(rootView: battery)

        XCTAssertGreaterThan(host.fittingSize.width, shorter.fittingSize.width,
            "The percentage is drawn, never reduced to an icon")
        XCTAssertEqual(battery.accessibilityValueText, "Level 60%, Discharging")
    }

    func testConnectionDetailsStackTheWidestPayloadsAsALabelAndValueList() {
        let list = VStack(alignment: .leading, spacing: PaddrStyle.Spacing.s2) {
            StatusDetailRow(
                title: "Access",
                value: LocalizedStringResource("Needed"),
                systemImage: "exclamationmark.shield",
                state: .problem
            )
            StatusDetailRow(
                title: "Puck",
                value: LocalizedStringResource("Not found"),
                systemImage: "cable.connector.slash",
                state: .problem
            )
            StatusDetailRow(
                title: "Controller",
                value: LocalizedStringResource("Not found"),
                systemImage: "gamecontroller",
                state: .problem
            )
            StatusDetailRow(
                title: "Output",
                value: LocalizedStringResource("Releasing"),
                systemImage: "pause.circle",
                state: .neutral
            )
            StatusDetailRow(
                title: "Battery",
                value: String("100%"),
                systemImage: "battery.100percent",
                state: .neutral
            )
        }
        let single = NSHostingView(rootView: StatusDetailRow(
            title: "Controller", value: LocalizedStringResource("Not found"),
            systemImage: "gamecontroller", state: .problem))
        let hostingView = NSHostingView(rootView: list)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            hostingView.fittingSize.height,
            (5 * single.fittingSize.height) + (4 * PaddrStyle.Spacing.s2),
            accuracy: 1,
            "Each value keeps its own line"
        )
        XCTAssertEqual(hostingView.fittingSize.width, single.fittingSize.width, accuracy: 1,
            "The list is as wide as its widest row, so every value shares the trailing edge")
        XCTAssertLessThan(hostingView.fittingSize.width,
            PaddrStyle.Metrics.minimumWindowSize.width - (2 * PaddrStyle.Metrics.outerSpacing))
    }

    private func assertApplyBarFitsMinimumWindow(
        model: PaddrMenuModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let controller = NSHostingController(rootView: ApplyBarView(model: model))
        let fitted = controller.sizeThatFits(
            in: NSSize(width: PaddrStyle.Metrics.minimumWindowSize.width, height: 400)
        )
        XCTAssertLessThanOrEqual(
            fitted.width,
            PaddrStyle.Metrics.minimumWindowSize.width + 0.5,
            file: file,
            line: line
        )
        XCTAssertGreaterThan(fitted.height, 0, file: file, line: line)
    }

    private func assertPendingProfilePicker(
        expectedName: String,
        operation: @MainActor (PaddrMenuModel) -> Bool
    ) async throws {
        let store = BlockingProfileStore()
        let model = PaddrMenuModel(dependencies: dependencies(store: store))
        defer { store.releaseSave() }

        let didInitialize = await waitUntil { model.isInitialized }
        XCTAssertTrue(didInitialize)
        XCTAssertTrue(operation(model))
        let didStartSave = await waitUntil { store.didStartSave }
        XCTAssertTrue(didStartSave)

        guard case let .switching(to: pendingID, named: pendingName) = model.profileSelectionPresentation else {
            return XCTFail("Expected a pending profile selection")
        }
        XCTAssertEqual(pendingName, expectedName)
        XCTAssertFalse(model.profiles.contains(where: { $0.id == pendingID }))

        let presentation = ProfilePickerPresentation(model: model)
        let pendingOption = try XCTUnwrap(presentation.options.first { $0.id == pendingID })
        XCTAssertEqual(pendingOption.label, "Switching to \(expectedName)…")
        XCTAssertEqual(presentation.accessibilityValue, "Switching to \(expectedName)")
    }

    private func accessibilityIntegerValue(of object: NSObject) -> Int? {
        let selector = NSSelectorFromString("accessibilityValue")
        guard object.responds(to: selector),
              let value = object.perform(selector)?.takeUnretainedValue() as? NSNumber else {
            return nil
        }
        return value.intValue
    }

    private func assertControlFits(
        _ control: NSControl,
        in hostingView: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = control.convert(control.bounds, to: hostingView)
        XCTAssertGreaterThanOrEqual(frame.minX, hostingView.bounds.minX - 0.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, hostingView.bounds.minY - 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, hostingView.bounds.maxX + 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, hostingView.bounds.maxY + 0.5, file: file, line: line)
    }

    private func descendants<ViewType: NSView>(
        of type: ViewType.Type,
        in view: NSView
    ) -> [ViewType] {
        let current = (view as? ViewType).map { [$0] } ?? []
        return current + view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    private func firstDescendant<ViewType: NSView>(
        of type: ViewType.Type,
        in view: NSView
    ) -> ViewType? {
        descendants(of: type, in: view).first
    }

    private func dependencies(
        store: BlockingProfileStore,
        session: any TrackpadSessionControlling = InertSession(),
        receiver: String? = nil
    ) -> MenuDependencies {
        MenuDependencies(
            session: session,
            loadProfiles: { ConfigurationProfileLoadResult(document: .default) },
            saveProfiles: store.save,
            probeReceiver: { receiver },
            accessibilityTrusted: { _ in true },
            openPrivacySettings: { _ in },
            sleep: { duration in try await Task.sleep(for: duration) },
            reconnectDelay: { _ in throw CancellationError() }
        )
    }

    private func settle(_ hostingView: NSView) async {
        for _ in 0..<6 {
            hostingView.layoutSubtreeIfNeeded()
            await Task.yield()
        }
    }

    private func makeWindow(
        hasToolbar: Bool,
        usesFullSizeContent: Bool
    ) -> NSWindow {
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if usesFullSizeContent { styleMask.insert(.fullSizeContentView) }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: PaddrStyle.Metrics.defaultWindowSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Paddr"
        window.toolbarStyle = .unifiedCompact
        window.collectionBehavior.insert(.fullScreenNone)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        if hasToolbar {
            window.contentViewController = NSHostingController(rootView: WindowToolbarProbe())
        } else {
            window.contentViewController = NSHostingController(rootView: Color.clear)
        }
        return window
    }

    private func assertSize(
        _ actual: NSSize,
        equals expected: NSSize,
        accuracy: CGFloat = 0.5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
    }
}

private final class WindowDelegateProbe: NSObject, NSWindowDelegate {}

private struct WindowToolbarProbe: View {
    var body: some View {
        Color.clear
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") {}
                }
            }
    }
}

private struct SettingsControlEdgeProbe: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
    }
}

private extension CGRect {
    func isApproximatelyEqual(to other: CGRect, accuracy: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) <= accuracy
            && abs(minY - other.minY) <= accuracy
            && abs(width - other.width) <= accuracy
            && abs(height - other.height) <= accuracy
    }
}

private struct InertSession: TrackpadSessionControlling {
    func start(
        configuration: PaddrConfiguration,
        observeOnly: Bool,
        outputGate: OutputGate?
    ) async -> AsyncStream<TrackpadSessionEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    @discardableResult
    func stop() async -> TrackpadSessionStopOutcome { .clean }
}

private actor PresentationSession: TrackpadSessionControlling {
    private var continuation: AsyncStream<TrackpadSessionEvent>.Continuation?
    private(set) var startCount = 0
    private(set) var startedWithOutputEnabled: [Bool] = []
    private(set) var lastConfiguration: PaddrConfiguration?

    func start(
        configuration: PaddrConfiguration,
        observeOnly: Bool,
        outputGate: OutputGate?
    ) async -> AsyncStream<TrackpadSessionEvent> {
        startCount += 1
        startedWithOutputEnabled.append(outputGate?.isEnabled ?? false)
        lastConfiguration = configuration
        let (stream, continuation) = AsyncStream<TrackpadSessionEvent>.makeStream()
        self.continuation = continuation
        return stream
    }

    @discardableResult
    func stop() async -> TrackpadSessionStopOutcome {
        continuation?.finish()
        continuation = nil
        return .clean
    }

    func send(_ event: TrackpadSessionEvent) {
        continuation?.yield(event)
    }
}

private final class BlockingProfileStore: @unchecked Sendable {
    private let gate = BoundedTestGate()
    private let lock = NSLock()
    private var saveStarted = false
    private var saveReleased = false

    var didStartSave: Bool {
        lock.withLock { saveStarted }
    }

    private let failsSave: Bool

    init(failsSave: Bool = false) { self.failsSave = failsSave }

    func save(_ document: ConfigurationProfileDocument) throws {
        let shouldWait = lock.withLock {
            saveStarted = true
            return !saveReleased
        }
        if shouldWait { gate.wait() }
        if failsSave { throw PaddrError.configuration("Fixture save failure") }
    }

    func releaseSave() {
        let shouldSignal = lock.withLock {
            guard !saveReleased else { return false }
            saveReleased = true
            return true
        }
        if shouldSignal {
            gate.signal()
        }
    }
}
