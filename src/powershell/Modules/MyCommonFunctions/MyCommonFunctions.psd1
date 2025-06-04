# MyCommonFunctions.psd1
@{
    RootModule = 'MyCommonFunctions.psm1'
    ModuleVersion = '0.1.0'
    GUID = '9ed4ddb2-7556-47be-aa95-b3d2ad69e04e' # [guid]::NewGuid() で生成
    Author = 'IT Legacy'
    Description = 'Provides common functions for the MD-WBS-Tools project.'
    FunctionsToExport = @(
        'Get-DecodedAndMappedAttribute',
        'ConvertTo-AttributeObject',
        'Reset-WbsCounters'  # ← これを追加
    )
}