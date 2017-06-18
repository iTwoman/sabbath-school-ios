/*
 * Copyright (c) 2017 Adventech <info@adventech.io>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import AsyncDisplayKit
import SwiftDate
import UIKit

class ReadController: ThemeController {
    let animator = PopupTransitionAnimator()
    
    var presenter: ReadPresenterProtocol?
    var collectionNode: ASPagerNode { return node as! ASPagerNode }
    
    var lessonInfo: LessonInfo?
    var reads = [Read]()
    var highlights = [ReadHighlights]()
    var comments = [ReadComments]()
    
    var shouldHideStatusBar = false
    var lastContentOffset: CGFloat = 0
    
    var menuItems = [UIMenuItem]()
    
    init() {
        super.init(node: ASPagerNode())
        self.collectionNode.backgroundColor = .baseGray1
        self.collectionNode.setDataSource(self)
        self.collectionNode.delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("storyboards are incompatible with truth and beauty")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setBackButton()
        presenter?.configure()
        setTransparentNavigation()

        for scrollGestureRecognizer in self.collectionNode.view.gestureRecognizers! {
            scrollGestureRecognizer.require(toFail: (self.navigationController?.interactivePopGestureRecognizer)!)
        }
        
        automaticallyAdjustsScrollViewInsets = false
        
        let rightButton = UIBarButtonItem(image: R.image.iconNavbarFont(), style: .done, target: self, action: #selector(readingOptions(sender:)))
        navigationItem.rightBarButtonItem = rightButton
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.navigationBar.hideBottomHairline()
        scrollBehavior()

        if let webView = (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.webView {
            webView.setupContextMenu()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return shouldHideStatusBar
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    func readingOptions(sender: UIBarButtonItem) {
        let buttonView = sender.value(forKey: "view") as! UIView
        let size = CGSize(width: round(node.frame.width)-10, height: 167)
        
        animator.style = .arrow
        animator.fromView = buttonView
        animator.interactive = false
        
        presenter?.presentReadOptionsScreen(size: size, transitioningDelegate: animator)
    }
    
    func toggleBars() {
        let shouldHide = !navigationController!.isNavigationBarHidden
        shouldHideStatusBar = shouldHide
        updateAnimatedStatusBar()
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }
    
    func updateAnimatedStatusBar() {
        UIView.animate(withDuration: 0.2, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
    }
    
    func scrollBehavior(){
        if reads.isEmpty {
            return
        }
        
        let scrollView = (collectionNode.nodeForPage(at: collectionNode.currentPageIndex) as! ReadView).webView.scrollView
        
        if let navigationBarHeight = self.navigationController?.navigationBar.frame.size.height {
            
            if (-scrollView.contentOffset.y <= UIApplication.shared.statusBarFrame.height + navigationBarHeight){
                title = (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.read?.title.uppercased()
                readNavigationBarStyle(color: .tintColor, titleColor: UIColor.white.withAlphaComponent(1-(-scrollView.contentOffset.y-navigationBarHeight)/navigationBarHeight))
            } else {
                title = ""
                setTransparentNavigation()
            }
        }
        
        if (scrollView.contentOffset.y + UIScreen.main.bounds.height >= scrollView.contentSize.height){
            if let navigationController = navigationController, navigationController.isNavigationBarHidden {
                toggleBars()
            }
        } else {
            if (-scrollView.contentOffset.y > 0 || lastContentOffset < -scrollView.contentOffset.y){
                if let navigationController = navigationController, navigationController.isNavigationBarHidden {
                    toggleBars()
                }
            } else {
                if let navigationController = navigationController, !navigationController.isNavigationBarHidden {
                    if scrollView.panGestureRecognizer.state != .possible {
                        toggleBars()
                    }
                }
            }
        }
        
        lastContentOffset = -scrollView.contentOffset.y
    }
    
    // TODO: - Refactor
    func readNavigationBarStyle(color: UIColor = .tintColor, titleColor: UIColor = .white){
        let theme = currentTheme()
        var colorPrimary = color
        if theme == ReaderStyle.Theme.Dark {
            setTranslucentNavigation(true, color: .readerDark, tintColor: .readerDarkFont, titleColor: .readerDarkFont)
            self.collectionNode.backgroundColor = .readerDark
            (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.coverOverlayNode.backgroundColor = .readerDark
            (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.coverNode.backgroundColor = .readerDark
            colorPrimary = .readerDark
        } else {
            setTranslucentNavigation(true, color: color, tintColor: .white, titleColor: titleColor)
            self.collectionNode.backgroundColor = .baseGray1
            (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.coverOverlayNode.backgroundColor = .tintColor
            (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.coverNode.backgroundColor = .tintColor
        }
        
        for webViewIndex in 0...self.reads.count {
            if self.collectionNode.currentPageIndex == webViewIndex { continue }
            (self.collectionNode.nodeForPage(at: webViewIndex) as? ReadView)?.coverOverlayNode.backgroundColor = colorPrimary
            (self.collectionNode.nodeForPage(at: webViewIndex) as? ReadView)?.coverNode.backgroundColor = colorPrimary
        }
    }
}

extension ReadController: ReadControllerProtocol {
    func loadLessonInfo(lessonInfo: LessonInfo){
        self.lessonInfo = lessonInfo
    }
    
    func showRead(read: Read, highlights: ReadHighlights, comments: ReadComments) {
        self.reads.append(read)
        self.highlights.append(highlights)
        self.comments.append(comments)
        self.collectionNode.reloadData()
    }
}

extension ReadController: ASPagerDataSource {
    func pagerNode(_ pagerNode: ASPagerNode, nodeBlockAt index: Int) -> ASCellNodeBlock {
        let read = reads[index]
        let readHighlights = highlights[index]
        let readComments = comments[index]
        let today = Date()
        
        let cellNodeBlock: () -> ASCellNode = {
            
            if today.isInSameDayOf(date: read.date){
                DispatchQueue.main.async {
                    self.collectionNode.scrollToPage(at: index, animated: false)
                }
            }
            
            return ReadView(lessonInfo: self.lessonInfo!, read: read, highlights: readHighlights, comments: readComments, delegate: self)
        }
        
        return cellNodeBlock
    }
    
    func numberOfPages(in pagerNode: ASPagerNode) -> Int {
        if lessonInfo != nil && !reads.isEmpty {
            return reads.count
        }
        return 0
    }
}

extension ReadController: ASCollectionDelegate {
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        scrollBehavior()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollBehavior()
    }
}

extension ReadController: ReadViewOutputProtocol {
    func didTapClearHighlight(){
        (collectionNode.nodeForPage(at: collectionNode.currentPageIndex) as! ReadView).webView.clearHighlight()
    }
    
    func didTapHighlight(color: String){
        (collectionNode.nodeForPage(at: collectionNode.currentPageIndex) as! ReadView).webView.highlight(color: color)
    }
    
    func didScrollView(readCellNode: ReadView, scrollView: UIScrollView) {
        scrollBehavior()
    }
    
    func didClickVerse(read: Read, verse: String) {
        let size = CGSize(width: round(node.frame.width*0.9), height: round(node.frame.height*0.8))
        
        animator.style = .square
        presenter?.presentBibleScreen(read: read, verse: verse, size: size, transitioningDelegate: animator)
        UIMenuController.shared.menuItems = []
    }
    
    func didLoadWebView(webView: UIWebView){
        UIView.animate(withDuration: 0.3) {
            webView.alpha = 1
        }
    }
    
    func didReceiveHighlights(readHighlights: ReadHighlights){
        presenter?.interactor?.saveHighlights(highlights: readHighlights)
    }
    
    func didReceiveComment(readComments: ReadComments){
        presenter?.interactor?.saveComments(comments: readComments)
    }
}

extension ReadController: ReadOptionsDelegate {
    func didSelectTheme(theme: String) {
        readNavigationBarStyle()
        for webViewIndex in 0...self.reads.count {
            (self.collectionNode.nodeForPage(at: webViewIndex) as? ReadView)?.webView.setTheme(theme)
        }
        
        scrollBehavior()
    }
    
    func didSelectTypeface(typeface: String){
        for webViewIndex in 0...self.reads.count {
            (self.collectionNode.nodeForPage(at: webViewIndex) as? ReadView)?.webView.setTypeface(typeface)
        }
    }
    
    func didSelectSize(size: String){
        for webViewIndex in 0...self.reads.count {
            (self.collectionNode.nodeForPage(at: webViewIndex) as? ReadView)?.webView.setSize(size)
        }
    }
}

extension ReadController: BibleControllerOutputProtocol {
    func didDismissBibleScreen() {
        if let webView = (self.collectionNode.nodeForPage(at: self.collectionNode.currentPageIndex) as? ReadView)?.webView {
            webView.createContextMenu()
        }
    }
}
