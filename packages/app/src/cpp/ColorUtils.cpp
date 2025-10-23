#include "ColorUtils.h"
#include <algorithm>
#include <cmath>

QColor ColorUtils::extractDominantColor(const QImage &image)
{
    if (image.isNull()) {
        return QColor(29, 185, 84);
    }

    QImage scaled = image.scaledToWidth(100, Qt::FastTransformation);

    int rSum = 0, gSum = 0, bSum = 0;
    int pixelCount = 0;

    for (int y = 0; y < scaled.height(); ++y) {
        for (int x = 0; x < scaled.width(); ++x) {
            QColor pixel = QColor::fromRgba(scaled.pixel(x, y));

            if (pixel.alpha() < 128)
                continue;

            rSum += pixel.red();
            gSum += pixel.green();
            bSum += pixel.blue();
            pixelCount++;
        }
    }

    if (pixelCount == 0) {
        return QColor(29, 185, 84);
    }

    QColor dominant;
    dominant.setRgb(rSum / pixelCount, gSum / pixelCount, bSum / pixelCount);
    return dominant;
}

ColorPalette ColorUtils::generatePaletteFromColor(const QColor &color)
{
    ColorPalette palette;
    palette.dominant = color;

    int h = color.hue();
    int s = color.saturation();
    int v = color.value();

    palette.accent.setHsv((h + 180) % 360, s, v);

    bool dark = isDarkColor(color);
    palette.background = dark ? color.lighter(120) : color.darker(120);

    QColor whiteText(255, 255, 255);
    QColor blackText(18, 18, 18);

    float contrastWithWhite = getContrastRatio(palette.background, whiteText);
    float contrastWithBlack = getContrastRatio(palette.background, blackText);

    palette.text = (contrastWithWhite >= 4.5) ? whiteText : blackText;
    palette.textSecondary = dark ? QColor(179, 179, 179) : QColor(102, 102, 102);

    return palette;
}

float ColorUtils::getRelativeLuminance(const QColor &color)
{
    auto linearize = [](float c) {
        c = c / 255.0f;
        return (c <= 0.03928f) ? c / 12.92f : std::pow((c + 0.055f) / 1.055f, 2.4f);
    };

    float r = linearize(color.red());
    float g = linearize(color.green());
    float b = linearize(color.blue());

    return 0.2126f * r + 0.7152f * g + 0.0722f * b;
}

float ColorUtils::getContrastRatio(const QColor &color1, const QColor &color2)
{
    float l1 = getRelativeLuminance(color1);
    float l2 = getRelativeLuminance(color2);

    float lighter = std::max(l1, l2);
    float darker = std::min(l1, l2);

    return (lighter + 0.05f) / (darker + 0.05f);
}

bool ColorUtils::isDarkColor(const QColor &color)
{
    return getRelativeLuminance(color) < 0.5f;
}
