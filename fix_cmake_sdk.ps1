# Script para agregar rutas del Windows SDK al CMakeLists.txt principal
$cmakeFile = "windows\CMakeLists.txt"
$sdkPath = "C:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0"

# Leer el contenido del archivo
$content = Get-Content $cmakeFile -Raw

# Buscar la función APPLY_STANDARD_SETTINGS y agregar las rutas del SDK
$pattern = 'target_compile_definitions\(\$\{TARGET\} PRIVATE "\$<\$<CONFIG:Debug\>:_DEBUG>"\)'
$replacement = @"
target_compile_definitions(`${TARGET} PRIVATE "$<`$<CONFIG:Debug>:_DEBUG>")
  # Add Windows SDK include paths for ATL
  if(EXISTS "$sdkPath")
    target_include_directories(`${TARGET} PRIVATE "$sdkPath/um")
    target_include_directories(`${TARGET} PRIVATE "$sdkPath/shared")
  endif()
"@

$newContent = $content -replace [regex]::Escape($pattern), $replacement

# Escribir el contenido modificado
$newContent | Out-File -FilePath $cmakeFile -Encoding utf8

Write-Host "CMakeLists.txt actualizado con rutas del Windows SDK"
