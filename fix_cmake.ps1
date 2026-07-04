$sdkPath = "C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0"
$content = Get-Content windows/CMakeLists.txt -Raw
$newContent = $content -replace 'target_compile_definitions\(\$\{TARGET\} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"\)', 'target_compile_definitions(`${TARGET} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")`n  # Add Windows SDK include paths for ATL`n  if(EXISTS "$sdkPath")`n    target_include_directories(`${TARGET} PRIVATE "$sdkPath/um")`n    target_include_directories(`${TARGET} PRIVATE "$sdkPath/shared")`n  endif()'
$newContent | Out-File -FilePath windows/CMakeLists.txt -Encoding utf8
