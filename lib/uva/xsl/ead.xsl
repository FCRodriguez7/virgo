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

  <xsl:template match="@*">
    <span>
      <xsl:attribute name="class">
        <xsl:value-of select="concat('ead-attribute ead-', local-name())"/>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:template match="*[ancestor::ead1:p | ancestor::p]" priority="-1">
    <xsl:variable name="content">
      <span>
        <xsl:choose>
          <xsl:when test="starts-with(local-name(), 'c0') or local-name() = 'c'">
            <xsl:attribute name="class">
              <xsl:text>ead-component</xsl:text>
            </xsl:attribute>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="class">
              <xsl:value-of select="concat('ead-element ead-', local-name())"/>
            </xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates/>
      </span>
    </xsl:variable>
    <xsl:if test="$content != ''">
      <xsl:copy-of select="$content"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*[not(ancestor::ead1:p | ancestor::p)]" priority="-1">
    <xsl:variable name="content">
      <div>
        <xsl:choose>
          <xsl:when test="starts-with(local-name(), 'c0') or local-name() = 'c'">
            <xsl:attribute name="class">
              <xsl:text>ead-component</xsl:text>
            </xsl:attribute>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="class">
              <xsl:value-of select="concat('ead-element ead-', local-name())"/>
            </xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates/>
      </div>
    </xsl:variable>
    <xsl:if test="$content != ''">
      <xsl:copy-of select="$content"/>
    </xsl:if>
  </xsl:template>

  <!-- Add any embedded images. -->
  <xsl:template match="ead1:extptr[@xlink:show='embed'] | extptr[@xlink:show='embed']">
    <img alt="decorative image">
      <xsl:attribute name="src">
        <xsl:value-of select="@xlink:href"/>
      </xsl:attribute>
    </img>
  </xsl:template>

  <!-- Add any links. -->
  <xsl:template match="ead1:extptr[@xlink:show='new'] | extptr[@xlink:show='new']">
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="@xlink:href"/>
        <xsl:value-of select="@href"/>
      </xsl:attribute>
      <xsl:value-of select="@xlink:title"/>
      <xsl:value-of select="@title"/>
    </a>
  </xsl:template>

  <xsl:template match="ead1:extref | extref">
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="@xlink:href"/>
        <xsl:value-of select="@href"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!--
    Convert title (from a component) into the very specifically branded pattern
    of HTML that is titles in Virgo.
  -->
  <xsl:template match="ead1:titleproper[not(ancestor::ead1:p)] | titleproper[not(ancestor::p)]">
    <div class="item-identifier-fields">
      <h1 class="title-field">
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates/>
      </h1>
    </div>
  </xsl:template>

  <xsl:template match="ead1:titleproper[ancestor::ead1:p] | titleproper[ancestor::p]">
    <div class="item-identifier-fields">
      <h1 class="title-field">
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates/>
      </h1>
    </div>
  </xsl:template>

  <!-- Convert "p" into "p". -->
  <xsl:template match="ead1:p | p">
    <p>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <!-- Convert "lb" into "br". -->
  <xsl:template match="ead1:lb | lb">
    <br/>
  </xsl:template>

  <!-- Convert simple lists into "ul". -->
  <xsl:template match="ead1:list[@type='simple'] | list[@type='simple']">
    <ul>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <!-- Convert list items into "li". -->
  <xsl:template match="ead1:list/ead1:item | list/item">
    <li>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </li>
  </xsl:template>

  <xsl:template match="ead1:list[@type='deflist'] | list[@type='deflist']">
    <dl>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </dl>
  </xsl:template>

  <xsl:template match="ead1:defitem/ead1:label | defitem/label">
    <dt>
      <xsl:apply-templates/>
    </dt>
  </xsl:template>

  <xsl:template match="ead1:defitem/ead1:item | defitem/item">
    <dd>
      <xsl:apply-templates/>
    </dd>
  </xsl:template>

  <xsl:template match="ead1:emph | emph">
    <em>
      <xsl:attribute name="class">
        <xsl:text>ead-</xsl:text><xsl:value-of select="@render"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </em>
  </xsl:template>

  <xsl:template match="ead1:title[@render='italic'] | title[@render='italic']">
    <em class="ead-element ead-title-italic">
      <xsl:apply-templates/>
    </em>
  </xsl:template>

  <xsl:template match="ead1:title[@render='doublequote'] | title[@render='doublequote']">
    <em class="ead-element ead-title-doublequote">
      <xsl:apply-templates/>
    </em>
  </xsl:template>

</xsl:stylesheet>
