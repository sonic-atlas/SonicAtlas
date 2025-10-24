#pragma once

#include <QColor>
#include <QImage>

struct ColorPalette
{
    QColor dominant;
    QColor accent;
    QColor background;
    QColor text;
    QColor textSecondary;
};

class ColorUtils
{
public:
    static QColor extractDominantColor(const QImage &image);
    static ColorPalette generatePaletteFromColor(const QColor &color);
    static float getRelativeLuminance(const QColor &color);
    static float getContrastRatio(const QColor &color1, const QColor &color2);
    static bool isDarkColor(const QColor &color);
};
