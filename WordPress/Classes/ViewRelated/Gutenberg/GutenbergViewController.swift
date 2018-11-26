import UIKit
import React
import WPMediaPicker

class GutenbergViewController: UIViewController, PostEditor {

    let errorDomain: String = "GutenbergViewController.errorDomain"

    private struct Analytics {
        static let editorSource = "gutenberg"
    }

    enum RequestHTMLReason {
        case publish
        case close
        case more
    }

    var html: String {
        set {
            post.content = newValue
        }
        get {
            return post.content ?? ""
        }
    }

    var postTitle: String

    /// Maintainer of state for editor - like for post button
    ///
    private(set) lazy var postEditorStateContext: PostEditorStateContext = {
        return PostEditorStateContext(post: post, delegate: self)
    }()

    var verificationPromptHelper: VerificationPromptHelper?

    var analyticsEditorSource: String {
        return Analytics.editorSource
    }

    var onClose: ((Bool, Bool) -> Void)?

    var isOpenedDirectlyForPhotoPost: Bool = false

    var isUploadingMedia: Bool {
        return false
    }

    func removeFailedMedia() {
        // TODO
    }

    var shouldRemovePostOnDismiss: Bool = false

    func cancelUploadOfAllMedia(for post: AbstractPost) {
        //TODO
    }

    func setHTML(_ html: String) {
        self.html = html
        //TODO: Update Gutenberg UI
    }

    func getHTML() -> String {
        return html
    }

    var post: AbstractPost {
        didSet {
            postEditorStateContext = PostEditorStateContext(post: post, delegate: self)
            refreshInterface()
        }
    }

    let navigationBarManager = PostEditorNavigationBarManager()

    lazy var mediaPickerHelper: GutenbergMediaPickerHelper = {
        return GutenbergMediaPickerHelper(context: self, post: post)
    }()

    var hasFailedMedia: Bool {
        return false
    }

    private var requestHTMLReason: RequestHTMLReason?

    /// For autosaving - The debouncer will execute local saving every defined number of seconds.
    /// In this case every 0.5 second
    ///
    fileprivate(set) lazy var debouncer: Debouncer = {
        return Debouncer(delay: PostEditorDebouncerConstants.autoSavingDelay, callback: debouncerCallback)
    }()

    /// Media Library Data Source
    ///
    lazy var mediaLibraryDataSource: MediaLibraryPickerDataSource = {
        return MediaLibraryPickerDataSource(post: self.post)
    }()

    private let gutenberg: Gutenberg

    required init(post: AbstractPost) {
        self.post = post
        self.postTitle = post.postTitle ?? ""
        self.gutenberg = Gutenberg(props: ["initialData": self.post.content ?? ""])
        self.verificationPromptHelper = AztecVerificationPromptHelper(account: self.post.blog.account)
        self.shouldRemovePostOnDismiss = post.hasNeverAttemptedToUpload()

        super.init(nibName: nil, bundle: nil)
        PostCoordinator.shared.cancelAnyPendingSaveOf(post: post)
        navigationBarManager.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    deinit {
        gutenberg.invalidate()
    }

    override func loadView() {
        view = gutenberg.rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createRevisionOfPost()
        configureNavigationBar()
        refreshInterface()

        gutenberg.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        verificationPromptHelper?.updateVerificationStatus()
    }

    func configureNavigationBar() {
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.accessibilityIdentifier = "Gutenberg Editor Navigation Bar"
        navigationItem.leftBarButtonItems = navigationBarManager.leftBarButtonItems
        navigationItem.rightBarButtonItems = navigationBarManager.rightBarButtonItems
    }

    func reloadBlogPickerButton() {
        var pickerTitle = post.blog.url ?? String()
        if let blogName = post.blog.settings?.name, blogName.isEmpty == false {
            pickerTitle = blogName
        }

        navigationBarManager.reloadBlogPickerButton(with: pickerTitle, enabled: !isSingleSiteMode)
    }

    func refreshInterface() {
        reloadBlogPickerButton()
        reloadPublishButton()
    }

    func contentByStrippingMediaAttachments() -> String {
        return html //TODO: return media attachment stripped version in future
    }

    @objc func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return presentationController(forPresented: presented, presenting: presenting)
    }
}

extension GutenbergViewController: GutenbergBridgeDelegate {

    func gutenbergDidRequestMediaPicker(callback: @escaping MediaPickerDidPickMediaCallback) {
        mediaPickerHelper.presentMediaPickerFullScreen(animated: true,
                                                       dataSourceType: .mediaLibrary,
                                                       callback: callback)
    }

    func gutenbergDidProvideHTML(_ html: String, changed: Bool) {
        self.html = html
        postEditorStateContext.updated(hasContent: editorHasContent)

        // TODO: currently we don't need to set this because Update button is always active
        // but in the future we might need this
        // postEditorStateContext.updated(hasChanges: changed)

        if let reason = requestHTMLReason {
            requestHTMLReason = nil // clear the reason
            switch reason {
            case .publish:
                handlePublishButtonTap()
            case .close:
                cancelEditing()
            case .more:
                displayMoreSheet()
            }
        }
    }
}

extension GutenbergViewController: PostEditorStateContextDelegate {

    func context(_ context: PostEditorStateContext, didChangeAction: PostEditorAction) {
        reloadPublishButton()
    }

    func context(_ context: PostEditorStateContext, didChangeActionAllowed: Bool) {
        reloadPublishButton()
    }

    func reloadPublishButton() {
        navigationBarManager.reloadPublishButton()
    }

}

extension GutenbergViewController: PostEditorNavigationBarManagerDelegate {
    var publishButtonText: String {
        return postEditorStateContext.publishButtonText
    }

    var isPublishButtonEnabled: Bool {
        // TODO: return postEditorStateContext.isPublishButtonEnabled when
        // we have the required bridge communication that informs us every change
        return true
    }

    var uploadingButtonSize: CGSize {
        return AztecPostViewController.Constants.uploadingButtonSize
    }

    func navigationBarManager(_ manager: PostEditorNavigationBarManager, closeWasPressed sender: UIButton) {
        requestHTMLReason = .close
        gutenberg.requestHTML()
    }

    func navigationBarManager(_ manager: PostEditorNavigationBarManager, moreWasPressed sender: UIButton) {
        requestHTMLReason = .more
        gutenberg.requestHTML()
    }

    func navigationBarManager(_ manager: PostEditorNavigationBarManager, blogPickerWasPressed sender: UIButton) {
        blogPickerWasPressed()
    }

    func navigationBarManager(_ manager: PostEditorNavigationBarManager, publishButtonWasPressed sender: UIButton) {
        requestHTMLReason = .publish
        gutenberg.requestHTML()
    }

    func navigationBarManager(_ manager: PostEditorNavigationBarManager, displayCancelMediaUploads sender: UIButton) {

    }
}