#pragma once

#include <QColor>
#include <QObject>

class ThemeManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QColor colorDominant READ colorDominant CONSTANT)
    Q_PROPERTY(QColor colorAccent READ colorAccent CONSTANT)
    Q_PROPERTY(QColor colorBackground READ colorBackground CONSTANT)
    Q_PROPERTY(QColor colorText READ colorText CONSTANT)
    Q_PROPERTY(QColor colorTextSecondary READ colorTextSecondary CONSTANT)

public:
    explicit ThemeManager(QObject *parent = nullptr);

    QColor colorDominant() const { return m_colorDominant; }
    QColor colorAccent() const { return m_colorAccent; }
    QColor colorBackground() const { return m_colorBackground; }
    QColor colorText() const { return m_colorText; }
    QColor colorTextSecondary() const { return m_colorTextSecondary; }

private:
    QColor m_colorDominant;
    QColor m_colorAccent;
    QColor m_colorBackground;
    QColor m_colorText;
    QColor m_colorTextSecondary;
};
