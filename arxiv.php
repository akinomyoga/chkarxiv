<?php

$title='Test';

?>
<?xml version="1.0" encoding="utf-8"?>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta http-equiv="Content-Style-Type" content="text/css" />
  <meta http-equiv="Content-Script-Type" content="text/javascript" />
  <title><?php echo $title;?></title>

  <link rel="stylesheet" type="text/css" charset="utf-8" href="/agh/mwg.std.css" />
  <meta name="agh-fly-type" content="tex" />
  <meta name="aghfly-reverts-symbols" content="1" />
  <script type="text/javascript" charset="utf-8" src="/agh/agh.fly.js"></script>
  <style type="text/css">
  .dateline,.descriptor{display:none;}

  .authors a{color:#008;}
  div.long-author-list{display:inline;}

  p.subjects{font-size:small;color:green;}
  span.subject-nucl-th,
  span.subject-nucl-ex,
  span.subject-hep-ex,
  span.subject-hep-ph{
    padding:.2ex .5ex;/*margin:0 1ex;*/
    font-weight:bold;
    color:white;background-color:#008;
  }
  span.subject-nucl-th{color:white;background-color:#008;}
  span.subject-hep-ex,
  span.subject-nucl-ex{color:white;background-color:#800;}
  span.subject-hep-ph{color:white;background-color:#080;}

  ul.article-index>li{font-weight:bold;}
  ul.article-index a.article-index-title{color:black;}
  </style>
</head>
<body class="aghfly-inline-math">
<h1><?php echo $title;?></h1>
<ul class="article-index">
<!--#%$cat .chkarxiv/index.tmp.htm-->
</ul>
<?php echo shell_exec('./chkarxiv.sh get-content-html 1610.');?>
</body>
</html>
