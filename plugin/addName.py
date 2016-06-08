#!/usr/bin/env python
#-*- coding:utf-8 -*-
##############################################
# Author        : shaojiayang           
# Email         : mightyang2@163.com    
# Last modified : 2016-06-09 00:23
# Filename      : addName.py
# Description   : 
##############################################

import markdown, re
from markdown.util import etree
from PySide import QtCore

idList = []

class addNamePreprocessor(markdown.preprocessors.Preprocessor):
    def run(self, lines):
        return lines

class addNameTreeprocessor(markdown.treeprocessors.Treeprocessor):
    def run(self, doc):
        for elem in doc:
            self.setId(elem)
    def setId(self, elem, parent=None):
        global idList
        pattern = r"name(\d+)$"
        if elem.text:
            result = re.findall(pattern, elem.text, re.S|re.M)
            if result:
                elem.text = re.sub(r"name\d+$", "", elem.text, flags=re.S|re.M)
                anchor = etree.Element("a", {"name":result[0]})
                elem.insert(0, anchor)
                anchor.tail = elem.text
                elem.text = ""
                idList.append(result[0])
        if elem.tail:
            result = re.findall(pattern, elem.tail, re.S|re.M)
            if result:
                elem.tail = re.sub(r"name\d+$", "", elem.tail, flags=re.S|re.M)
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

class addNamePostprocessor(markdown.postprocessors.Postprocessor):
    def run(self, text):
        return text

class addNameExtension(markdown.extensions.Extension):
    def __init__(self, configs={}):
        self.config = configs
    def extendMarkdown(self, md, md_globals):
        md.registerExtension(self)
        addNamePro = addNamePreprocessor()
        md.preprocessors.add("addNamePro", addNamePro, "<normalize_whitespace")
        addNameTree = addNameTreeprocessor()
        md.treeprocessors.add("addNameTree", addNameTree, "<prettify")
        addNamePost = addNamePostprocessor()
        md.postprocessors.add("addNamePost", addNamePost, ">unescape")
