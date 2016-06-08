#!/usr/bin/env python
#-*- coding:utf-8 -*-
##############################################
# Author        : shaojiayang           
# Email         : mightyang2@163.com    
# Last modified : 2016-06-08 23:48
# Filename      : flowChart.py
# Description   : 
##############################################

import markdown
from markdown.util import etree

class flowChartPreprocessor(markdown.preprocessors.Preprocessor):
    def run(self, lines):
        return lines

class flowChartTreeprocessor(markdown.treeprocessors.Treeprocessor):
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

class flowChartPostprocessor(markdown.postprocessors.Postprocessor):
    def run(self, text):
        return text

class flowChartExtension(markdown.extensions.Extension):
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

