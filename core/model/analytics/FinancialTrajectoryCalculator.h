#pragma once

#include "FinancialTrajectory.h"

class FinancialTrajectoryCalculator
{
public:
    static QVector<FinancialTrajectoryPoint> calculate(
        const FinancialTrajectoryInput& input);
};
