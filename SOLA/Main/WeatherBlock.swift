import SwiftUI

// Bloc météo de l'accueil : condition + température du jour, puis bande 7 jours
// (condition réelle Open-Meteo + temp max + UV max). Données : ForecastStore.
struct WeatherBlock: View {
    let forecast: UVForecast

    var body: some View {
        CardBox(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                // Aujourd'hui
                HStack(spacing: 12) {
                    Image(systemName: forecast.condition.sfSymbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Palette.amberDeep)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(forecast.temperature))° · \(forecast.condition.label)")
                            .font(SolaFont.body(15.5, weight: .bold)).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text("UV \(forecast.current.formatted(.number.precision(.fractionLength(0...1)))) · max \(forecast.maxToday.formatted(.number.precision(.fractionLength(0...1))))")
                            .font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }

                if !forecast.daily.isEmpty {
                    Divider().background(Palette.lineSoft)
                    // Cette semaine
                    HStack(spacing: 0) {
                        ForEach(Array(forecast.daily.prefix(7).enumerated()), id: \.offset) { _, d in
                            VStack(spacing: 5) {
                                Text(d.dayLabel)
                                    .font(SolaFont.body(11, weight: .semibold)).foregroundStyle(Palette.ink3)
                                    .lineLimit(1)
                                Image(systemName: d.condition.sfSymbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Palette.amberDeep)
                                Text("\(Int(d.tempMax))°")
                                    .font(SolaFont.body(12, weight: .bold)).foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                Text("UV\(Int(d.uvMax.rounded()))")
                                    .font(SolaFont.mono(10)).foregroundStyle(Palette.ink3)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}
