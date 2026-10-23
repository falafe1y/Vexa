#pragma once

#include "../core/model/FinancialTrajectory.h"

class FinancialTrajectoryCalculator
{
public:
    static QVector<FinancialTrajectoryPoint> calculate(
        const FinancialTrajectoryInput& input);
};
