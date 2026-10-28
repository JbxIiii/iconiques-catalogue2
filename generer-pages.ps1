# Crée une page par motif (m/ICS-00043.html), son image d'aperçu pour WhatsApp et Facebook
# (images/og/ICS-00043.jpg, 1200 x 630) et le sitemap.xml pour Google, à partir de catalogue.json.
# À lancer après generer-vignettes.ps1, chaque fois que le catalogue change.
# Les images d'aperçu déjà créées ne sont pas refaites, sauf avec le paramètre -Tout.

param([switch]$Tout)

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
Set-Location $PSScriptRoot

$SITE = 'https://iconiquess.com'
$WHATSAPP = '22677956781'
$GOATCOUNTER = 'sarabi'
$CATEGORIES = @{
    'tuniques' = 'Tuniques frappe et poche'; 'trois-pieces' = 'Trois-pièces'; 'agbada' = 'Agbada'
    'modeles-dames' = 'Modèles dames'; 'motifs-divers' = 'Motifs divers'
}
$fr = [Globalization.CultureInfo]::GetCultureInfo('fr-FR')
$utf8 = New-Object Text.UTF8Encoding $false

function Enc($s) { [Net.WebUtility]::HtmlEncode([string]$s) }
function Prix($n) { ([double]$n).ToString('N0', $fr) + ' FCFA' }
function Mini($img) { $img -replace '^images/(.+)\.\w+$', 'images/mini/$1.jpg' }
function Hd($img) { $img -replace '^images/(.+)\.\w+$', 'images/hd/$1.jpg' }
function Url($path) { ($path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/' }

function Couleur($hex) { [Windows.Media.ColorConverter]::ConvertFromString($hex) }
function Pinceau($hex) { New-Object Windows.Media.SolidColorBrush (Couleur $hex) }
function Texte($dc, $txt, $police, $graisse, $taille, $hex, $x, $y, $largeurMax) {
    $tf = New-Object Windows.Media.Typeface (New-Object Windows.Media.FontFamily $police), ([Windows.FontStyles]::Normal), $graisse, ([Windows.FontStretches]::Normal)
    $ft = New-Object Windows.Media.FormattedText $txt, $fr, ([Windows.FlowDirection]::LeftToRight), $tf, $taille, (Pinceau $hex), 1.0
    if ($largeurMax) { $ft.MaxTextWidth = $largeurMax; $ft.MaxLineCount = 2; $ft.Trimming = 'CharacterEllipsis' }
    $dc.DrawText($ft, (New-Object Windows.Point $x, $y))
    return $ft.Height
}
function Jpeg($visual, $w, $h, $dst, $qualite) {
    $rt = New-Object Windows.Media.Imaging.RenderTargetBitmap $w, $h, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rt.Render($visual)
    $enc = New-Object Windows.Media.Imaging.JpegBitmapEncoder
    $enc.QualityLevel = $qualite
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rt))
    $fs = [IO.File]::Create($dst); $enc.Save($fs); $fs.Close()
}
function Charger($path) {
    $s = [IO.File]::OpenRead((Resolve-Path -LiteralPath $path).Path)
    $f = [Windows.Media.Imaging.BitmapDecoder]::Create($s, 'None', 'OnLoad').Frames[0]
    $s.Close(); return $f
}

# Image d'aperçu : l'affiche à gauche, le nom et le prix à droite, aux couleurs du site.
function Apercu($m, $dst) {
    $W = 1200; $Hh = 630
    $dv = New-Object Windows.Media.DrawingVisual
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($dv, 'HighQuality')
    $dc = $dv.RenderOpen()
    $dc.DrawRectangle((Pinceau '#161412'), $null, (New-Object Windows.Rect 0, 0, $W, $Hh))
    $src = if (Test-Path -LiteralPath (Hd $m.img)) { Hd $m.img } else { $m.img }
    $img = Charger $src
    $ph = 550; $pw = [math]::Round($img.PixelWidth * $ph / $img.PixelHeight)
    $dc.DrawRectangle((Pinceau '#C9972F'), $null, (New-Object Windows.Rect 58, 38, ($pw + 4), ($ph + 4)))
    $dc.DrawImage($img, (New-Object Windows.Rect 60, 40, $pw, $ph))
    $x = 60 + $pw + 70; $lw = $W - $x - 60
    Etoile $dc ($x + 14) 88 15 '#C9972F'
    $null = Texte $dc 'ICONIQUES S' 'Segoe UI' ([Windows.FontWeights]::Normal) 32 '#FAF6EF' ($x + 42) 68 $lw
    $pointille = New-Object Windows.Media.Pen (Pinceau '#C9972F'), 3
    $pointille.DashStyle = New-Object Windows.Media.DashStyle ([double[]](4, 2.7)), 0
    $dc.DrawLine($pointille, (New-Object Windows.Point $x, 130), (New-Object Windows.Point ($x + 260), 130))
    $y = 175
    $y += Texte $dc $m.title.Trim() 'Segoe UI Light' ([Windows.FontWeights]::Light) 76 '#FAF6EF' $x $y $lw
    $y += 14
    $null = Texte $dc ($m.ref + '  ·  ' + $CATEGORIES[$m.cat]) 'Segoe UI' ([Windows.FontWeights]::SemiBold) 30 '#E0B04F' $x $y $lw
    $null = Texte $dc (Prix $m.prixNum) 'Segoe UI' ([Windows.FontWeights]::SemiBold) 64 '#FAF6EF' $x 410 $lw
    $null = Texte $dc 'Commandez sur WhatsApp  ·  iconiquess.com' 'Segoe UI' ([Windows.FontWeights]::Normal) 26 '#ADA290' $x 525 $lw
    $dc.Close()
    Jpeg $dv $W $Hh $dst 85
}

# Étoile à quatre branches de l'icône, centrée sur (cx, cy).
function Etoile($dc, $cx, $cy, $r, $hex) {
    $k = $r * 0.08
    $g = [Windows.Media.Geometry]::Parse("M $cx,$($cy-$r) Q $($cx+$k),$($cy-$k) $($cx+$r),$cy Q $($cx+$k),$($cy+$k) $cx,$($cy+$r) Q $($cx-$k),$($cy+$k) $($cx-$r),$cy Q $($cx-$k),$($cy-$k) $cx,$($cy-$r) Z")
    $dc.DrawGeometry((Pinceau $hex), $null, $g)
}

# Icônes de l'application, du site et de l'écran d'accueil iPhone, toutes tirées de icone-source.png.
function Png($src, $taille, $dst) {
    $dv = New-Object Windows.Media.DrawingVisual
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($dv, 'HighQuality')
    $dc = $dv.RenderOpen()
    $dc.DrawImage($src, (New-Object Windows.Rect 0, 0, $taille, $taille))
    $dc.Close()
    $rt = New-Object Windows.Media.Imaging.RenderTargetBitmap $taille, $taille, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rt.Render($dv)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rt))
    $ms = New-Object IO.MemoryStream; $enc.Save($ms)
    if ($dst) { [IO.File]::WriteAllBytes($dst, $ms.ToArray()) }
    return ,$ms.ToArray()
}
function Icones {
    $src = Charger 'icone-source.png'
    foreach ($t in 512, 192) { $null = Png $src $t "icon-$t.png" }
    $null = Png $src 180 'apple-touch-icon.png'
    # favicon.ico : 16, 32 et 48 px, chacun stocké en PNG dans le fichier .ico
    $tailles = 16, 32, 48
    $pngs = $tailles | ForEach-Object { ,(Png $src $_ $null) }
    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$tailles.Count)
    $offset = 6 + 16 * $tailles.Count
    for ($i = 0; $i -lt $tailles.Count; $i++) {
        $w.Write([byte]$tailles[$i]); $w.Write([byte]$tailles[$i]); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($p in $pngs) { $w.Write($p) }
    $w.Flush(); [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot 'favicon.ico'), $ms.ToArray())
}

function Page($m, $similaires) {
    $ref = $m.ref; $titre = $m.title.Trim(); $cat = $CATEGORIES[$m.cat]; $prix = Prix $m.prixNum
    $nbCouleurs = [int]("0" + $m.couleurs)
    $couleurs = if ($nbCouleurs -gt 1) { "$nbCouleurs couleurs" } elseif ($nbCouleurs -eq 1) { '1 couleur' } else { '' }
    $url = "$SITE/m/$ref"
    $desc = "Motif de broderie numérisé $titre ($ref), $cat" + $(if ($couleurs) { ", $couleurs de fil" } else { '' }) + ". $prix. Commandez sur WhatsApp et recevez le fichier sur WhatsApp."
    $wa = "https://wa.me/$WHATSAPP?text=" + [Uri]::EscapeDataString("Bonjour ICONIQUES S, je souhaite commander ce motif :`n`n• $ref « $titre » : $prix`n$url`n`nMerci de me confirmer le format pour ma machine et le paiement.")
    $hd = '/' + (Url (Hd $m.img))
    $ld = [ordered]@{
        '@context' = 'https://schema.org'; '@type' = 'Product'; name = $titre; sku = $ref; category = $cat
        image = "$SITE$hd"; description = $desc; brand = @{ '@type' = 'Brand'; name = 'ICONIQUES S' }
        offers = [ordered]@{ '@type' = 'Offer'; price = [string]$m.prixNum; priceCurrency = 'XOF'; availability = 'https://schema.org/InStock'; url = $url }
    } | ConvertTo-Json -Depth 4 -Compress
    $simHtml = ($similaires | ForEach-Object {
        "<a href=""/m/$($_.ref)""><img src=""/$(Url (Mini $_.img))"" alt="""" loading=""lazy"" width=""400"" height=""711""><span>$(Enc $_.title.Trim())</span><span class=""p"">$(Enc (Prix $_.prixNum))</span></a>"
    }) -join "`n                "
    $specCouleurs = if ($couleurs) { "<div><dt>Couleurs de fil</dt><dd>$nbCouleurs</dd></div>" } else { '' }
@"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(Enc $titre) — Motif de broderie $(Enc $cat) | ICONIQUES S</title>
    <meta name="description" content="$(Enc $desc)">
    <link rel="canonical" href="$url">
    <meta name="theme-color" content="#161412" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#1B1916" media="(prefers-color-scheme: dark)">
    <meta name="color-scheme" content="light dark">
    <meta property="og:type" content="product">
    <meta property="og:locale" content="fr_FR">
    <meta property="og:site_name" content="ICONIQUES S">
    <meta property="og:url" content="$url">
    <meta property="og:title" content="$(Enc $titre) — $(Enc $prix)">
    <meta property="og:description" content="$(Enc $desc)">
    <meta property="og:image" content="$SITE/images/og/$ref.jpg">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:image:alt" content="Motif de broderie $(Enc $titre)">
    <meta property="product:price:amount" content="$($m.prixNum)">
    <meta property="product:price:currency" content="XOF">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:image" content="$SITE/images/og/$ref.jpg">
    <link rel="icon" href="/favicon.ico" sizes="any">
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
    <link rel="manifest" href="/manifest.webmanifest">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Jost:wght@300;400;500;600&display=swap" rel="stylesheet">
    <script type="application/ld+json">$ld</script>
    <link rel="stylesheet" href="/m/motif.css">
</head>
<body>
    <header class="top"><div class="wrap"><a class="brand" href="/"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 0C12.6 7.6 16.4 11.4 24 12 16.4 12.6 12.6 16.4 12 24 11.4 16.4 7.6 12.6 0 12 7.6 11.4 11.4 7.6 12 0Z"/></svg>ICONIQUES S</a><a class="back" href="/#catalogue">Tous les motifs</a></div><div class="stitch"></div></header>
    <main class="wrap motif">
        <a class="media" href="/?ref=$ref"><img src="$hd" alt="Motif de broderie $(Enc $titre)" width="810" height="1440"></a>
        <div class="info">
            <p class="ref">$ref</p>
            <h1>$(Enc $titre)</h1>
            <p class="price">$(Enc $prix)</p>
            <dl class="specs">
                <div><dt>Catégorie</dt><dd>$(Enc $cat)</dd></div>
                $specCouleurs
            </dl>
            <div class="actions">
                <a class="btn primary" href="$(Enc $wa)" target="_blank" rel="noopener noreferrer" data-goatcounter-click="commander-$ref">Commander sur WhatsApp</a>
                <a class="btn secondary" href="/?ref=$ref">Voir dans le catalogue</a>
            </div>
            <p class="note">Paiement par Wave ou Orange Money. Le fichier est envoyé sur WhatsApp après confirmation du paiement, au format de votre machine.</p>
            <section class="similar">
                <h2>Dans la même catégorie</h2>
                <div class="grid">
                $simHtml
                </div>
            </section>
        </div>
    </main>
    <footer class="foot"><div class="wrap">ICONIQUES S · Ouagadougou, Burkina Faso · <a href="https://wa.me/$WHATSAPP">WhatsApp +226 77 95 67 81</a></div></footer>
    <script data-goatcounter="https://$GOATCOUNTER.goatcounter.com/count" async src="//gc.zgo.at/count.js"></script>
</body>
</html>
"@
}

$catalogue = Get-Content catalogue.json -Raw -Encoding UTF8 | ConvertFrom-Json
$motifs = @($catalogue | Where-Object { $_.ref -and $_.title -and -not $_.draft })
New-Item -ItemType Directory -Force 'm', 'images\og' | Out-Null

# Pages des motifs retirés du catalogue : on les supprime.
Get-ChildItem m -Filter 'ICS-*.html' | Where-Object { $motifs.ref -notcontains $_.BaseName } | Remove-Item

$nOg = 0
foreach ($m in $motifs) {
    $memes = @($motifs | Where-Object { $_.cat -eq $m.cat })
    $i = [array]::IndexOf($memes, $m)
    $similaires = @(for ($k = 1; $k -lt [math]::Min(5, $memes.Count); $k++) { $memes[($i + $k) % $memes.Count] })
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot "m\$($m.ref).html"), (Page $m $similaires), $utf8)
    $og = Join-Path $PSScriptRoot "images\og\$($m.ref).jpg"
    if ($Tout -or -not (Test-Path -LiteralPath $og)) { Apercu $m $og; $nOg++ }
}

# Pour changer d'icône : remplacer icone-source.png (carré, 1024 px conseillé) puis lancer avec -Tout.
if ($Tout -or -not (Test-Path 'icon-512.png')) { Icones }

$jour = (Get-Date).ToString('yyyy-MM-dd')
$urls = @("  <url><loc>$SITE/</loc><lastmod>$jour</lastmod><changefreq>weekly</changefreq><priority>1.0</priority></url>")
$urls += $motifs | ForEach-Object {
    $d = if ($_.ajout) { $_.ajout } else { $jour }
    "  <url><loc>$SITE/m/$($_.ref)</loc><lastmod>$d</lastmod><priority>0.7</priority></url>"
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'sitemap.xml'), "<?xml version=""1.0"" encoding=""UTF-8""?>`n<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">`n$($urls -join "`n")`n</urlset>`n", $utf8)

Write-Host "$($motifs.Count) pages de motifs, $nOg image(s) d'aperçu, sitemap mis à jour."
