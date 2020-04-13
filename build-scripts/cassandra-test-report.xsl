<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
        xmlns:lxslt="http://xml.apache.org/xslt"
        xmlns:string="xalan://java.lang.String">
<xsl:output method="html" indent="yes" encoding="UTF-8"
  doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN" />
<xsl:decimal-format decimal-separator="." grouping-separator="," />
<!--
   Licensed to the Apache Software Foundation (ASF) under one or more
   contributor license agreements.  See the NOTICE file distributed with
   this work for additional information regarding copyright ownership.
   The ASF licenses this file to You under the Apache License, Version 2.0
   (the "License"); you may not use this file except in compliance with
   the License.  You may obtain a copy of the License at

       https://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 -->

<!-- Sample stylesheet copied and modified from ant's junit-noframes.xsl -->

<!-- the result is intended to be piped through html2text so any html formatting is minimal -->
<xsl:template match="testsuites">
    <html>
        <body>
            <xsl:call-template name="summary"/>
            <hr size="1" width="95%" align="left"/>
            <xsl:call-template name="packagelist"/>
            <hr size="1" width="95%" align="left"/>
            <hr size="1" width="95%" align="left"/>
            <xsl:call-template name="packages"/>
            <hr size="1" width="95%" align="left"/>
            <xsl:call-template name="classes"/>
            <hr size="1" width="95%" align="left"/>
            END<!-- marker incase the file is truncated -->
        </body>
    </html>
</xsl:template>


    <xsl:template name="packagelist">
        <!-- Note: package statistics are not computed recursively, they only sum up all of its testsuites numbers. -->
        <table class="details" border="0" cellpadding="5" cellspacing="2" width="95%">
            <xsl:call-template name="testsuite.test.header"/>
            <!-- list all packages recursively -->
            <xsl:for-each select="./testsuite[not(./@package = preceding-sibling::testsuite/@package)]">
                <xsl:sort select="@package"/>
                <xsl:variable name="testsuites-in-package" select="/testsuites/testsuite[./@package = current()/@package]"/>
                <xsl:variable name="testCount" select="sum($testsuites-in-package/@tests)"/>
                <xsl:variable name="errorCount" select="sum($testsuites-in-package/@errors)"/>
                <xsl:variable name="failureCount" select="sum($testsuites-in-package/@failures)"/>
                <xsl:variable name="skippedCount" select="sum($testsuites-in-package/@skipped)" />
                <xsl:variable name="timeCount" select="sum($testsuites-in-package/@time)"/>
                <!-- write a summary for the package -->
                <tr valign="top">
                    <!-- set a nice color depending if there is an error/failure -->
                    <xsl:attribute name="class">
                        <xsl:choose>
                            <xsl:when test="$failureCount &gt; 0">Failure</xsl:when>
                            <xsl:when test="$errorCount &gt; 0">Error</xsl:when>
                        </xsl:choose>
                    </xsl:attribute>
                    <td><xsl:value-of select="@package"/></td>
                    <td><xsl:value-of select="$testCount"/></td>
                    <td><xsl:value-of select="$errorCount"/></td>
                    <td><xsl:value-of select="$failureCount"/></td>
                    <td><xsl:value-of select="$skippedCount" /></td>
                    <td>
                    <xsl:call-template name="display-time">
                        <xsl:with-param name="value" select="$timeCount"/>
                    </xsl:call-template>
                    </td>
                </tr>
            </xsl:for-each>
        </table>
    </xsl:template>

    <xsl:template name="packages">
        Packages
        <hr size="1" width="95%" align="left"/>
        <xsl:for-each select="/testsuites/testsuite[not(./@package = preceding-sibling::testsuite/@package)]">
            <xsl:sort select="@package"/>
                <xsl:value-of select="@package"/>
                <table class="details" border="0" cellpadding="5" cellspacing="2" width="95%">
                    <xsl:call-template name="testsuite.test.header"/>
                    <xsl:apply-templates select="/testsuites/testsuite[./@package = current()/@package]" mode="print.test"/>
                </table>
                <hr size="1" width="95%" align="left"/>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="classes">
        Failures
        <hr size="1" width="95%" align="left"/>
        <table class="details" border="0" cellpadding="5" cellspacing="2" width="95%">
            <xsl:for-each select="testsuite">
                <xsl:sort select="@name"/>
                <xsl:if test="./error"><!-- test can even not be started at all (failure to load the class) so report the error directly -->
                    <tr><td colspan="4"><xsl:value-of select="@name"/></td></tr>
                    <tr class="Error">
                        <td colspan="4"><xsl:apply-templates select="./error"/></td>
                    </tr>
                </xsl:if>
                <xsl:apply-templates select="./testcase" mode="print.failures"/>
            </xsl:for-each>
        </table>
        <hr size="1" width="95%" align="left"/>
        Skipped
        <hr size="1" width="95%" align="left"/>
        <table class="details" border="0" cellpadding="5" cellspacing="2" width="95%">
            <xsl:for-each select="testsuite">
                <xsl:sort select="@name"/>
                <xsl:apply-templates select="./testcase" mode="print.skipped"/>
            </xsl:for-each>
        </table>
    </xsl:template>

    <xsl:template name="summary">
        Cassandra CI Results
        <hr size="1" width="95%" align="left"/>
        <xsl:variable name="testCount" select="sum(testsuite/@tests)"/>
        <xsl:variable name="errorCount" select="sum(testsuite/@errors)"/>
        <xsl:variable name="failureCount" select="sum(testsuite/@failures)"/>
        <xsl:variable name="skippedCount" select="sum(testsuite/@skipped)" />
        <xsl:variable name="timeCount" select="sum(testsuite/@time)"/>
        <xsl:variable name="successRate" select="($testCount - $failureCount - $errorCount) div $testCount"/>
        <table class="details" border="0" cellpadding="5" cellspacing="10">
        <tr>
            <th>Tests</th>
            <th>Failures</th>
            <th>Errors</th>
            <th>Skipped</th>
            <th>Success rate</th>
            <th>Time</th>
        </tr>
        <tr>
            <xsl:attribute name="class">
                <xsl:choose>
                    <xsl:when test="$failureCount &gt; 0">Failure</xsl:when>
                    <xsl:when test="$errorCount &gt; 0">Error</xsl:when>
                </xsl:choose>
            </xsl:attribute>
            <td><xsl:value-of select="$testCount"/></td>
            <td><xsl:value-of select="$failureCount"/></td>
            <td><xsl:value-of select="$errorCount"/></td>
            <td><xsl:value-of select="$skippedCount" /></td>
            <td>
                <xsl:call-template name="display-percent">
                    <xsl:with-param name="value" select="$successRate"/>
                </xsl:call-template>
            </td>
            <td>
                <xsl:call-template name="display-time">
                    <xsl:with-param name="value" select="$timeCount"/>
                </xsl:call-template>
            </td>
        </tr>
        </table>
    </xsl:template>

<xsl:template match="testsuite" mode="header">
    <tr valign="top">
        <th width="90%">Name</th>
        <th>Tests</th>
        <th>Errors</th>
        <th>Failures</th>
        <th>Skipped</th>
        <th nowrap="nowrap">Time(s)</th>
    </tr>
</xsl:template>

<!-- class header -->
<xsl:template name="testsuite.test.header">
    <tr valign="top">
        <th width="90%">Name</th>
        <th>Tests</th>
        <th>Errors</th>
        <th>Failures</th>
        <th>Skipped</th>
        <th nowrap="nowrap">Time(s)</th>
    </tr>
</xsl:template>

<!-- class information -->
<xsl:template match="testsuite" mode="print.test">
    <tr valign="top">
        <!-- set a nice color depending if there is an error/failure -->
        <xsl:attribute name="class">
            <xsl:choose>
                <xsl:when test="@failures[.&gt; 0]">Failure</xsl:when>
                <xsl:when test="@errors[.&gt; 0]">Error</xsl:when>
            </xsl:choose>
        </xsl:attribute>

        <!-- print testsuite information -->
        <td><xsl:value-of select="@name"/></td>
        <td><xsl:value-of select="@tests"/></td>
        <td><xsl:value-of select="@errors"/></td>
        <td><xsl:value-of select="@failures"/></td>
        <td><xsl:value-of select="@skipped" /></td>
        <td>
            <xsl:call-template name="display-time">
                <xsl:with-param name="value" select="@time"/>
            </xsl:call-template>
        </td>
    </tr>
</xsl:template>

<xsl:template match="testcase" mode="print.failures">
    <xsl:choose>
        <xsl:when test="failure">
            <tr><td colspan="4"><xsl:value-of select="../@name"/> // <xsl:value-of select="@name"/> // Failure</td></tr>
            <tr><td colspan="4"><xsl:apply-templates select="failure"/></td></tr>
            <tr><td colspan="4"><hr size="1" width="95%" align="left"/></td></tr>
        </xsl:when>
        <xsl:when test="error">
            <tr><td colspan="4"><xsl:value-of select="../@name"/> // <xsl:value-of select="@name"/> // Error</td></tr>
            <tr><td colspan="4"><xsl:apply-templates select="error"/></td></tr>
            <tr><td colspan="4"><hr size="1" width="95%" align="left"/></td></tr>
        </xsl:when>
    </xsl:choose>
</xsl:template>

<xsl:template match="testcase" mode="print.skipped">
    <xsl:if test="skipped">
        <tr><td colspan="4"><xsl:value-of select="../@name"/><br/><xsl:value-of select="@name"/></td></tr>
        <tr><td colspan="4"><xsl:apply-templates select="skipped"/></td></tr>
        <tr><td colspan="4"><hr size="1" width="95%" align="left"/></td></tr>
    </xsl:if>
</xsl:template>

<xsl:template match="failure">
    <xsl:call-template name="display-failures"/>
</xsl:template>

<xsl:template match="error">
    <xsl:call-template name="display-failures"/>
</xsl:template>

<xsl:template match="skipped">
    <xsl:call-template name="display-failures"/>
</xsl:template>

<!-- Style for the error, failure and skipped in the testcase template -->
<xsl:template name="display-failures">
    <xsl:choose>
        <xsl:when test="not(@message)"></xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="@message"/>
        </xsl:otherwise>
    </xsl:choose>
    <!-- display the stacktrace -->
    <code>
        <br/><br/>
        <xsl:call-template name="br-replace">
            <xsl:with-param name="word" select="."/>
        </xsl:call-template>
    </code>
    <!-- the later is better but might be problematic for non-21" monitors... -->
    <!--pre><xsl:value-of select="."/></pre-->
</xsl:template>

<xsl:template name="JS-escape">
    <xsl:param name="string"/>
    <xsl:param name="tmp1" select="string:replaceAll(string:new(string($string)),'\\','\\\\')"/>
    <xsl:param name="tmp2" select="string:replaceAll(string:new(string($tmp1)),&quot;'&quot;,&quot;\\&apos;&quot;)"/>
    <xsl:param name="tmp3" select="string:replaceAll(string:new(string($tmp2)),&quot;&#10;&quot;,'\\n')"/>
    <xsl:param name="tmp4" select="string:replaceAll(string:new(string($tmp3)),&quot;&#13;&quot;,'\\r')"/>
    <xsl:value-of select="$tmp4"/>
</xsl:template>


<!--
    template that will convert a carriage return into a br tag
    @param word the text from which to convert CR to BR tag
-->
<xsl:template name="br-replace">
    <xsl:param name="word"/>
    <xsl:param name="splitlimit">32</xsl:param>
    <xsl:variable name="secondhalfstartindex" select="(string-length($word)+(string-length($word) mod 2)) div 2"/>
    <xsl:variable name="secondhalfword" select="substring($word, $secondhalfstartindex)"/>
    <!-- When word is very big, a recursive replace is very heap/stack expensive, so subdivide on line break after middle of string -->
    <xsl:choose>
      <xsl:when test="(string-length($word) > $splitlimit) and (contains($secondhalfword, '&#xa;'))">
        <xsl:variable name="secondhalfend" select="substring-after($secondhalfword, '&#xa;')"/>
        <xsl:variable name="firsthalflen" select="string-length($word) - string-length($secondhalfword)"/>
        <xsl:variable name="firsthalfword" select="substring($word, 1, $firsthalflen)"/>
        <xsl:variable name="firsthalfend" select="substring-before($secondhalfword, '&#xa;')"/>
        <xsl:call-template name="br-replace">
          <xsl:with-param name="word" select="concat($firsthalfword,$firsthalfend)"/>
        </xsl:call-template>
        <br/>
        <xsl:call-template name="br-replace">
          <xsl:with-param name="word" select="$secondhalfend"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($word, '&#xa;')">
        <xsl:value-of select="substring-before($word, '&#xa;')"/>
        <br/>
        <xsl:call-template name="br-replace">
          <xsl:with-param name="word" select="substring-after($word, '&#xa;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$word"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="display-time">
    <xsl:param name="value"/>
    <xsl:value-of select="format-number($value,'0.000')"/>
</xsl:template>

<xsl:template name="display-percent">
    <xsl:param name="value"/>
    <xsl:value-of select="format-number($value,'0.00%')"/>
</xsl:template>

</xsl:stylesheet>
