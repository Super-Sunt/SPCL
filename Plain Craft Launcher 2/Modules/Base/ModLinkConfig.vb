''' <summary>
''' 联机功能的本地配置，替代官方服务器下发的 ServerConfig("Link")。
''' </summary>
Friend Module ModLinkConfig

    ''' <summary>
    ''' 内置联机模块（EasyTier）版本号。更换内置模块时必须 +1，启动器据此判断是否需要重新安装。
    ''' </summary>
    Public Const EasyTierVersion As Integer = 3

    ''' <summary>
    ''' 允许联机的最低内部构建号。
    ''' </summary>
    Public Const MinVersionCode As Integer = 411

    ''' <summary>
    ''' EasyTier 基础启动参数（原由官方服务器下发）。其余参数由联机页按角色拼接。
    ''' </summary>
    Public Const BaseArguments As String = ""

    ''' <summary>
    ''' 内置模块缺失时的回退下载地址，{arch} 会替换为 x86_64 / i686 / arm64。
    ''' </summary>
    Public ReadOnly FallbackDownloads As String() = {
        "https://ghfast.top/https://github.com/EasyTier/EasyTier/releases/download/v2.6.4/easytier-windows-{arch}-v2.6.4.zip",
        "https://github.com/EasyTier/EasyTier/releases/download/v2.6.4/easytier-windows-{arch}-v2.6.4.zip"
    }

    ''' <summary>
    ''' 当前应连接的节点列表：自定义节点优先，其次是中继服务器设置。
    ''' </summary>
    Public Function GetRelayPeers() As String
        Dim Custom As String = Settings.Get(Of String)("LinkCustomPeer")
        If Not String.IsNullOrWhiteSpace(Custom) Then Return Custom
        Return Settings.Get(Of String)("LinkRelayServer")
    End Function

    ''' <summary>
    ''' 发布包内置的联机模块文件夹（与 exe 同级）。缺少必需文件时返回 Nothing。
    ''' </summary>
    Public ReadOnly Property BundledModuleFolder As String
        Get
            Dim Folder As String = Paths.Base & "联机模块\"
            If FileUtils.Exists(Folder & "联机模块.exe") AndAlso
               FileUtils.Exists(Folder & "联机模块 CLI.exe") AndAlso
               FileUtils.Exists(Folder & "Packet.dll") Then Return Folder
            Return Nothing
        End Get
    End Property

End Module