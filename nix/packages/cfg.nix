{runCommand, ...}:
runCommand "euler-cfg-source" {} ''
  cp -r ${../../src} $out
''
