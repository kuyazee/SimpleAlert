//
//  SimpleAlert.swift
//  SimpleAlert
//
//  Created by Kyohei Ito on 2015/01/09.
//  Copyright (c) 2015年 kyohei_ito. All rights reserved.
//

import UIKit

open class AlertController: UIViewController {
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var backgroundView: UIView! {
        didSet {
            if preferredStyle == .actionSheet {
                tapGesture.addTarget(self, action: #selector(AlertController.backgroundViewTapAction(_:)))
                backgroundView.addGestureRecognizer(tapGesture)
            }
        }
    }
    @IBOutlet weak var marginView: UIView!
    @IBOutlet weak var contentBaseView: UIView!
    @IBOutlet weak var cancelBaseView: UIView!
    @IBOutlet weak var contentView: UIScrollView!
    @IBOutlet weak var alertButtonView: UIScrollView!
    @IBOutlet weak var cancelButtonView: UIScrollView!
    @IBOutlet weak var alertContentView: AlertContentView!

    @IBOutlet weak var containerViewWidth: NSLayoutConstraint!
    @IBOutlet weak var containerViewBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var backgroundViewTopSpace: NSLayoutConstraint!
    @IBOutlet weak var backgroundViewBottomSpace: NSLayoutConstraint!

    @IBOutlet weak var contentViewHeight: NSLayoutConstraint!
    @IBOutlet weak var alertButtonViewHeight: NSLayoutConstraint!
    @IBOutlet weak var cancelbuttonViewHeight: NSLayoutConstraint!
    @IBOutlet weak var spaceBetweenAlertAndCancel: NSLayoutConstraint! {
        didSet {
            if preferredStyle == .actionSheet {
                spaceBetweenAlertAndCancel.constant = ActionSheetMargin
            }
        }
    }
    
    @IBOutlet weak var marginViewTopSpace: NSLayoutConstraint!
    @IBOutlet weak var marginViewLeftSpace: NSLayoutConstraint!
    @IBOutlet weak var marginViewBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var marginViewRightSpace: NSLayoutConstraint!

    @discardableResult
    public func configureContentView(_ block: @escaping (UIView) -> Void) -> Self {
        configContentView = block
        return self
    }

    var configContentView: ((UIView) -> Void)?

    public private(set) var actions: [AlertAction] = []
    public var textFields: [UITextField] {
        return alertContentView?.textFields ?? []
    }
    open var contentWidth: CGFloat = 270
    open var contentColor: UIColor? = .white
    open var contentCornerRadius: CGFloat = 3
    open var coverColor: UIColor = .black
    open var message: String?

    private var textFieldHandlers: [((UITextField) -> Void)?] = []
    private var customView: UIView?
    private var preferredStyle: UIAlertControllerStyle = .alert
    private let tapGesture = UITapGestureRecognizer()
    let ActionSheetMargin: CGFloat = 8

    private var marginInsets: UIEdgeInsets {
        set {
            marginViewLeftSpace.constant = newValue.left
            marginViewRightSpace.constant = newValue.right
            if #available(iOS 11.0, *) {
                marginViewTopSpace.constant = view.safeAreaInsets.top
                marginViewBottomSpace.constant = view.safeAreaInsets.bottom
            } else {
                let height = UIApplication.shared.statusBarFrame.height
                marginViewTopSpace.constant = height == 0 ? newValue.top : height
                marginViewBottomSpace.constant = newValue.bottom
            }
        }
        get {
            let top = marginViewTopSpace.constant
            let left = marginViewLeftSpace.constant
            let bottom = marginViewBottomSpace.constant
            let right = marginViewRightSpace.constant
            return UIEdgeInsetsMake(top, left, bottom, right)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private convenience init() {
        self.init(nibName: "SimpleAlert", bundle: Bundle(for: AlertController.self))
    }

    public convenience init(title: String?, message: String?, style: UIAlertControllerStyle) {
        self.init()
        self.title = title
        self.message = message
        self.preferredStyle = style
    }

    public convenience init(view: UIView?, style: UIAlertControllerStyle) {
        self.init()
        self.title = "custom"
        self.message = "view"
        customView = view
        preferredStyle = style
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        modalPresentationStyle = .custom
        modalTransitionStyle = .crossDissolve
        transitioningDelegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(AlertController.keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AlertController.keyboardDidHide(_:)), name: .UIKeyboardDidHide, object: nil)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        contentBaseView.clipsToBounds = true
        cancelBaseView.clipsToBounds = true

        if #available(iOS 11.0, *) {
            contentView.contentInsetAdjustmentBehavior = .never
            alertButtonView.contentInsetAdjustmentBehavior = .never
            cancelButtonView.contentInsetAdjustmentBehavior = .never
        }

        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerViewBottomSpace.isActive = preferredStyle == .actionSheet
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        contentBaseView.backgroundColor = contentColor
        cancelBaseView.backgroundColor = contentColor
        contentBaseView.layer.cornerRadius = contentCornerRadius
        cancelBaseView.layer.cornerRadius = contentCornerRadius

        if let view = customView {
            view.autoresizingMask = .flexibleWidth
            view.frame.size.width = alertContentView.containerView.bounds.width
            alertContentView.containerView.addSubview(view)
        }

        alertContentView.titleLabel.text = title
        alertContentView.messageLabel.text = message

        if preferredStyle == .alert {
            for handler in textFieldHandlers {
                let textField = alertContentView.addTextField()
                handler?(textField)
            }

            textFieldHandlers.removeAll()
            textFields.first?.becomeFirstResponder()
        }
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        layoutContainer()
        layoutContents()
        layoutButtons()

        let margin = marginInsets.top + marginInsets.bottom
        let backgroundViewHeight = view.bounds.size.height - backgroundViewBottomSpace.constant - margin
        
        if cancelButtonView.contentSize.height > cancelbuttonViewHeight.constant {
            cancelbuttonViewHeight.constant = cancelButtonView.contentSize.height
        }
        
        if cancelbuttonViewHeight.constant > backgroundViewHeight {
            cancelButtonView.contentSize.height = cancelbuttonViewHeight.constant
            cancelbuttonViewHeight.constant = backgroundViewHeight
            
            contentViewHeight.constant = 0
            alertButtonViewHeight.constant = 0
        } else {
            let baseViewHeight = backgroundViewHeight - cancelbuttonViewHeight.constant - spaceBetweenAlertAndCancel.constant
            if alertButtonView.contentSize.height > alertButtonViewHeight.constant {
                alertButtonViewHeight.constant = alertButtonView.contentSize.height
            }
            
            if alertButtonViewHeight.constant > baseViewHeight {
                alertButtonView.contentSize.height = alertButtonViewHeight.constant
                alertButtonViewHeight.constant = baseViewHeight
                contentViewHeight.constant = 0
            } else {
                let mainViewHeight = baseViewHeight - alertButtonViewHeight.constant
                if contentViewHeight.constant > mainViewHeight {
                    contentView.contentSize.height = contentViewHeight.constant
                    contentViewHeight.constant = mainViewHeight
                }
            }
        }
    }

    public func addTextField(configurationHandler: ((UITextField) -> Void)? = nil) {
        textFieldHandlers.append(configurationHandler)
    }

    public func addAction(_ action: AlertAction) {
        action.button.frame.size.height = preferredStyle.buttonHeight
        action.button.addTarget(self, action: #selector(AlertController.buttonWasTapped(_:)), for: .touchUpInside)

        configureActionButton(action.button, at: action.style)
        actions.append(action)
    }

    open func configureActionButton(_ button: UIButton, at style: AlertAction.Style) {
        if style == .destructive {
            button.setTitleColor(.red, for: .normal)
        }
        button.titleLabel?.font = style.font(of: preferredStyle)
    }
}

private extension AlertController {
    func layoutContainer() {
        let containerWidth: CGFloat
        if preferredStyle == .actionSheet {
            marginInsets = UIEdgeInsetsMake(ActionSheetMargin, ActionSheetMargin, ActionSheetMargin, ActionSheetMargin)
            containerWidth = min(view.bounds.width, view.bounds.height) - marginInsets.left - marginInsets.right
        } else {
            containerWidth = contentWidth
        }

        containerViewWidth.constant = containerWidth
        containerView.layoutIfNeeded()
    }
    
    func layoutContents() {
        alertContentView.frame.size.width = contentView.frame.size.width

        if let config = configContentView {
            config(alertContentView)
            configContentView = nil
        }

        alertContentView.textViewHeightConstraint.constant = 0
        alertContentView.layoutContents()

        contentViewHeight.constant = alertContentView.bounds.height
        contentView.addSubview(alertContentView)
    }

    func layoutButtons() {
        let containerWidth = containerViewWidth.constant
        let buttonActions: [AlertAction]

        if preferredStyle == .actionSheet {
            buttonActions = actions.filter { $0.style != .cancel }

            let cancelActions = actions.filter { $0.style == .cancel }
            layoutButtonVertically(with: cancelActions, width: containerWidth).forEach(cancelButtonView.addAction)
            cancelbuttonViewHeight.constant = cancelActions.last?.button.frame.maxY ?? 0
        } else {
            buttonActions = actions
        }

        if preferredStyle == .alert && actions.count == 2 {
            layoutButtonHorizontally(with: buttonActions, width: containerWidth).forEach(alertButtonView.addAction)
            buttonActions.last?.addVerticalBorder()
        } else {
            layoutButtonVertically(with: buttonActions, width: containerWidth).forEach(alertButtonView.addAction)
        }
        alertButtonViewHeight.constant = buttonActions.last?.button.frame.maxY ?? 0
    }

    func layoutButtonVertically(with actions: [AlertAction], width: CGFloat) -> [AlertAction] {
        return actions
            .reduce([]) { actions, action in
                action.button.frame.size.width = width
                action.button.frame.origin.y = actions.last?.button.frame.maxY ?? 0
                return actions + [action]
            }
    }

    func layoutButtonHorizontally(with actions: [AlertAction], width: CGFloat) -> [AlertAction] {
        return actions
            .reduce([]) { actions, action in
                action.button.frame.size.width = width / 2
                action.button.frame.origin.x = actions.last?.button.frame.maxX ?? 0
                return actions + [action]
        }
    }

    func dismiss(with sender: UIButton) {
        guard let action = actions.filter({ $0.button == sender }).first else {
            dismiss()
            return
        }
        if action.dismissesAlert {
            dismiss {
                action.handler?(action)
            }
        } else {
            action.handler?(action)
        }
    }

    func dismiss(withCompletion block: @escaping () -> Void = {}) {
        dismiss(animated: true) {
            block()
            self.actions.removeAll()
            self.alertContentView.textFields.removeAll()
        }
    }
}

// MARK: - Action Methods
private extension AlertController {
    @objc func buttonWasTapped(_ button: UIButton) {
        dismiss(with: button)
    }

    @objc func backgroundViewTapAction(_ gesture: UITapGestureRecognizer) {
        dismiss()
    }
}

// MARK: - NSNotificationCenter Methods
extension AlertController {
    @objc func keyboardDidHide(_ notification: Notification) {
        backgroundViewBottomSpace?.constant = 0
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let frame = notification.info.endFrame, let rect = view.window?.convert(frame, to: view) {
            backgroundViewBottomSpace?.constant = view.bounds.size.height - rect.origin.y
        }
    }
}

// MARK: - UIViewControllerTransitioningDelegate Methods
extension AlertController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch preferredStyle {
        case .alert:
            return AlertControllerPresentTransition(backgroundColor: coverColor)
        case .actionSheet:
            return ActionSheetControllerPresentTransition(backgroundColor: coverColor, topSpace: self.backgroundViewTopSpace, bottomSpace: self.backgroundViewBottomSpace)
        }
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch preferredStyle {
        case .alert:
            return AlertControllerDismissTransition(backgroundColor: coverColor)
        case .actionSheet:
            return ActionSheetControllerDismissTransition(backgroundColor: coverColor, topSpace: self.backgroundViewTopSpace, bottomSpace: self.backgroundViewBottomSpace)
        }
    }
}
