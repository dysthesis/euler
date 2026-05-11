{runCommand, ...}:
runCommand "euler-cfg" {} ''
  cp -r ${../../src} $out
''
