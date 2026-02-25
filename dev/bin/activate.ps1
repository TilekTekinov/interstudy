# . bin/activate.ps1
$global:_OLD_JANET_PATH=$env:JANET_PATH
$global:_OLD_PATH=$env:PATH
$env:JANET_PATH="C:\Users\josef\code\interstudy\dev"
$env:PATH=$env:JANET_PATH + "\bin;" + $env:PATH
$function:old_prompt = $function:prompt
function global:prompt {
  Write-Host "(dev) " -NoNewline
  & $function:old_prompt
}
function deactivate {
  $env:PATH=$global:_OLD_PATH
  $env:JANET_PATH=$global:_OLD_JANET_PATH
  Remove-Item function:\deactivate
  $function:prompt = $function:old_prompt
  Remove-Item function:\old_prompt
}