function! PyMarkdownPreview()
python << EOF
import vim, markdown, sys, time, re, logging, os, base64
from PySide import QtGui, QtCore, QtWebKit
from threading import Thread
from markdown.util import etree

logging.basicConfig(level=logging.ERROR,
                    format="%(asctime)s %(filename)s[line:%(lineno)d] %(levelname)s %(message)s",
                    filename=os.getenv("temp")+"/myapp.log",
                    filemod="w")

logging.debug( "="*10 )

idList = []

class addIDPreprocessor(markdown.preprocessors.Preprocessor):
    def run(self, lines):
        return lines

class addIDTreeprocessor(markdown.treeprocessors.Treeprocessor):
    def run(self, doc):
        for elem in doc:
            self.setId(elem)
    def setId(self, elem, parent=None):
        global idList
        pattern = r"id(\d+)$"
        if elem.text:
            result = re.findall(pattern, elem.text, re.S|re.M)
            if result:
                elem.text = re.sub(r"id\d+$", "", elem.text, flags=re.S|re.M)
                anchor = etree.Element("a", {"name":result[0]})
                elem.insert(0, anchor)
                anchor.tail = elem.text
                elem.text = ""
                idList.append(result[0])
        if elem.tail:
            result = re.findall(pattern, elem.tail, re.S|re.M)
            if result:
                elem.tail = re.sub(r"id\d+$", "", elem.tail, flags=re.S|re.M)
                anchor = etree.Element("a", {"name":result[0]})
                parent.insert(0, anchor)
                anchor.tail = parent.text
                parent.text = ""
                idList.append(result[0])
        if elem.tag == "img":
            if QtCore.QDir(elem.attrib["src"]).isRelative():
                elem.attrib["src"] = QtCore.QDir.currentPath()+"/"+elem.attrib["src"]
        if len(list(elem))>0:
            for child in list(elem):
                self.setId(child, elem)

class addIDPostprocessor(markdown.postprocessors.Postprocessor):
    def run(self, text):
        return text

class addIDExtension(markdown.extensions.Extension):
    def __init__(self, configs={}):
        self.config = configs
    def extendMarkdown(self, md, md_globals):
        md.registerExtension(self)
        addIDPro = addIDPreprocessor()
        md.preprocessors.add("addIDPro", addIDPro, "<normalize_whitespace")
        addIDTree = addIDTreeprocessor()
        md.treeprocessors.add("addIDTree", addIDTree, "<prettify")
        addIDPost = addIDPostprocessor()
        md.postprocessors.add("addIDPost", addIDPost, ">unescape")

class pyMarkdownBrowserWidget(QtWebKit.QWebView):
    def __init__ (self, parent=None):
        global idList
        logging.debug("initialize browser")
        QtWebKit.QWebView.__init__(self, parent)
        #self.setWindowFlags(QtCore.Qt.FramelessWindowHint)
        self.page = QtWebKit.QWebPage()
        self.setPage(self.page)
        self.follow = True
        self.customStyleSheet()
        logging.debug("start follow thread")
        #rpt = Thread(target=self.rePositionForever)
        #rpt.setDaemon(True)
        #rpt.start()
        self.refreshHtml()

    def customStyleSheet(self):
        self.viewSettings = self.settings()
        self.viewSettings.setUserStyleSheetUrl(QtCore.QUrl(u"data:text/css;charset=utf-8;base64," +\
        base64.b64encode('body {background-color:#DDDDDD;font-family: Microsoft YaHei;}\
        h1 {background-color: #AAAAAA;}\
        h2 {background-color: #C0C0C0;}\
        h3 {background-color: #CCCCCC;}\
        p {text-indent: 2em;}\
        hr {height:5px;border:none;border-top:5px solid #555555;}\
        blockquote {\
          background: #EEEEEE;\
          border-left: 10px solid #ccc;\
          margin: 1.5em 10px;\
          padding: 0.5em 10px;\
        }\
        blockquote:before {\
          color: #ccc;\
          content: open-quote;\
          font-size: 4em;\
          line-height: 0.1em;\
          margin-right: 0.25em;\
          vertical-align: -0.4em;\
        }\
        blockquote p {\
          display: inline;\
        }\
        pre {\
            font-family: "Courier 10 Pitch", Courier, monospace;\
            font-size: 95%;\
            border-top: 10px solid #888888;\
            border-bottom: 1px solid #AAAAAA;\
            padding: 5px;\
            padding-left: 10px;\
            line-height: 140%;\
            white-space: pre;\
            white-space: pre-wrap;\
            white-space: -moz-pre-wrap;\
            white-space: -o-pre-wrap;\
            background: #C8C8C8;\
        }\
        code {\
            font-family: Monaco, Consolas, "Andale Mono", "DejaVu Sans Mono", monospace;\
            font-size: 95%;\
            line-height: 140%;\
            white-space: pre;\
            white-space: pre-wrap;\
            white-space: -moz-pre-wrap;\
            white-space: -o-pre-wrap;\
        }\
        th {\
            border:2px solid #333333;\
        }\
        td {\
            border:1px solid #555555;\
        }\
        thead {\
            background-color:#AAAAAA;\
            padding: 8px;\
            border:2px solid #333333;\
        }\
        tbody {\
            background-color:#CCCCCC;\
            padding: 8px;\
            border:1px solid #333333;\
        }\
        table {\
            width:100%;\
            border:1px solid #333333;\
        }\
        '.encode("utf-8"))
        ))

    def isH(self, text):
        pattern = re.compile("^([-=*]+)$")
        results = pattern.findall(text)
        if results!=[] :
            return True
        else:
            return False

    def refreshHtml(self):
        global idList
        logging.debug("refresh html")
        newbf = []
        idList = []
        for i in range(len(vim.current.buffer)):
            if vim.current.buffer[i].strip()!="":
                if not self.isH(vim.current.buffer[i]):
                    newbf.append(vim.current.buffer[i] + "id%d"%(i+1))
                else:
                    newbf.append(vim.current.buffer[i])
            else:
                newbf.append(vim.current.buffer[i])
        self.bf = unicode("\n".join(newbf), "utf8")
        self.html = markdown.markdown(self.bf, extensions=["markdown.extensions.tables", addIDExtension({})])
        self.html = u'<html>\n<head>\n<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>\n</head>\n<body>\n' + self.html
        self.html += u'\n<br>'*100
        self.html += u'</body>\n</html>'
        self.page.mainFrame().setHtml(self.html)

    def writeHtml(self, path):
        f = open(path, "w")
        f.write(self.page.mainFrame().toHtml().encode("utf-8"))
        f.close()

    def writeImg(self, path):
        size = self.page.mainFrame().contentsSize()
        sourceSize = self.page.viewportSize()
        self.page.setViewportSize(QtCore.QSize(size.width()+16, size.height()))
        img = QtGui.QImage(size, QtGui.QImage.Format_ARGB32)
        painter = QtGui.QPainter(img)
        self.page.mainFrame().render(painter)
        painter.end()
        self.page.setViewportSize(sourceSize)
        img.save(path)

    def switchVisible(self):
        if self.isVisible():
            logging.debug("I am hide")
            self.hide()
        else:
            self.refreshHtml()
            logging.debug("I am show")
            self.show()

    def rePositionForever(self):
        while(self.follow):
            self.rePosition()
            time.sleep(0.5)

    def rePosition(self):
        vim.command("let vimPosX = getwinposx()")
        vim.command("let vimPosY = getwinposy()")
        vim.command("let vimRow= winheight(0)")
        vim.command("let vimCol= winwidth(0)")
        self.x = int(vim.eval("vimPosX"))
        self.y = int(vim.eval("vimPosY"))
        self.width = int(vim.eval("vimCol"))*8+25
        self.height = int(vim.eval("vimRow"))*17
        self.setGeometry(self.x+self.width, self.y, 800 , self.height+50)

    def reScroll(self):
        self.page.mainFrame().scrollToAnchor(self.getAvailableLine(vim.eval("line('.')")))
        self.scrollRelativePixel()

    def getAvailableLine(self, currentPos):
        addMode = 1
        addCp = int(currentPos)
        minusCp = addCp
        for i in range(50):
            if addMode:
                if str(addCp) in idList:
                    return str(addCp)
                else:
                    addCp += 1
            else:
                if str(minusCp) in idList:
                    return str(minusCp)
                else:
                    minusCp -= 1
            addMode = 1-addMode
            i+=1

    def scrollRelativePixel(self):
        vim.command("let lineWinPercent = (line('.')-line('w0')+1)*1.0/(line('w$')-line('w0')+1)")
        lwp = float(vim.eval("lineWinPercent"))
        self.height = int(vim.eval("vimRow"))*17
        relativePixel = self.height*lwp
        self.page.mainFrame().setScrollBarValue(QtCore.Qt.Vertical, self.page.mainFrame().scrollBarValue(QtCore.Qt.Vertical)-relativePixel)

    def closeBrowser(self):
        logging.debug("I am close")
        self.follow = False
        self.close()
        QtCore.QCoreApplication.instance().exit()

EOF
endfunc

function! PySideApp()
python <<EOF
app = QtCore.QCoreApplication.instance()
if app == None:
    logging.debug( "create pyside app" )
    app = QtGui.QApplication(sys.argv)
    appExists = False

logging.debug( "start app thread" )
if not appExists:
    t = Thread(target=app.exec_)
    t.setDaemon(True)
    t.start()
EOF
endfun

function! PyMarkdownBrowserStartup()
call PyMarkdownPreview()
call PySideApp()
python <<EOF
if "pyMarkdownBrowser" in dir():
    logging.debug( "close preview pyMarkdownBrowser" )
    if not pyMarkdownBrowser.isVisible():
        pyMarkdownBrowser.show()
        #pyMarkdownBrowser.refreshHtml()
else:
    pyMarkdownBrowser = pyMarkdownBrowserWidget()
    pyMarkdownBrowser.show()
    #pyMarkdownBrowser.refreshHtml()
EOF
endfunc

function! PyMarkdownPreviewVisible()
python << EOF
pyMarkdownBrowser.switchVisible()
EOF
endfunc

function! PyMarkdownPreviewShow()
python << EOF
pyMarkdownBrowser.show()
EOF
endfunc

function! PyMarkdownPreviewHide()
python << EOF
pyMarkdownBrowser.hide()
EOF
endfunc

function! PyMarkdownPreviewRefresh()
let vimRow = winheight(0)
python << EOF
pyMarkdownBrowser.refreshHtml()
pyMarkdownBrowser.reScroll()
EOF
endfunc

function! PyMarkdownPreviewReScroll()
let vimRow = winheight(0)
python << EOF
pyMarkdownBrowser.reScroll()
EOF
endfunc

function! PyMarkdownPreviewRePosition()
python << EOF
pyMarkdownBrowser.rePosition()
EOF
endfunc

function! PyMarkdownPreviewWriteHtml(htmlPath)
python << EOF
pyMarkdownBrowser.writeHtml(vim.eval("a:htmlPath"))
EOF
endfunc

function! PyMarkdownPreviewWriteImg(imgPath)
python << EOF
pyMarkdownBrowser.writeImg(vim.eval("a:imgPath"))
EOF
endfunc

command -nargs=1 WriteHtml call PyMarkdownPreviewWriteHtml("<args>")
command -nargs=1 WriteImg call PyMarkdownPreviewWriteImg("<args>")
autocmd! BufRead,BufReadPost,FileReadPost *.md,*.markdown call PyMarkdownBrowserStartup()
autocmd! TextChanged,TextChangedI *.md,*.markdown call PyMarkdownPreviewRefresh()
autocmd! BufEnter *.md,*.markdown call PyMarkdownPreviewShow()
autocmd! BufLeave *.md,*.markdown call PyMarkdownPreviewHide()
autocmd! CursorMoved *.md,*.markdown call PyMarkdownPreviewReScroll()
