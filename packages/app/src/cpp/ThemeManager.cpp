#include "ThemeManager.h"

ThemeManager::ThemeManager(QObject *parent)
    : QObject(parent)
    , m_colorDominant(29, 185, 84)
    , m_colorAccent(26, 163, 74)
    , m_colorBackground(18, 18, 18)
    , m_colorText(255, 255, 255)
    , m_colorTextSecondary(179, 179, 179)
{}
