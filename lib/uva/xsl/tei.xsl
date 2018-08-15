<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:xlink="http://www.w3.org/1999/xlink"
                xmlns:xi="http://www.w3.org/2001/XInclude"
                xmlns:ead1="urn:isbn:1-931666-22-9">

  <xsl:output omit-xml-declaration="yes" encoding="UTF-8" media-type="text/xml"
              indent="yes"/>

  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="*|@*" priority="-1">
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="body">
    <div class="tei-body">
      <xsl:apply-templates mode="body"/>
    </div>
  </xsl:template>

  <xsl:template match="lb" mode="body">
    <br/>
  </xsl:template>

  <xsl:template match="*" mode="body">
    <xsl:variable name="content">
      <div>
        <xsl:attribute name="class">
          <xsl:value-of select="concat('tei-element tei-', local-name())"/>
          <xsl:for-each select="@rend">
            <xsl:value-of select="concat('-', local-name(), '_', .)"/>
          </xsl:for-each>
        </xsl:attribute>
        <xsl:apply-templates mode="body"/>
      </div>
    </xsl:variable>
    <xsl:if test="$content != ''">
      <xsl:copy-of select="$content"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
