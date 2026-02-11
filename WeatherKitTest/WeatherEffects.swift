import SwiftUI// MARK: - Weather Effects\n

struct StarsEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appVisibility: AppVisibility

    private struct Star: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let baseOpacity: Double
        let twinkleSpeed: Double
        let delay: Double
    }

    @State private var stars: [Star] = []

    var body: some View {
        let shouldAnimate = appVisibility.effectsActive && !reduceMotion
        Group {
            if shouldAnimate {
                TimelineView(.animation) { timeline in
                    starsLayer(time: timeline.date.timeIntervalSinceReferenceDate, animate: true)
                }
            } else {
                // Static stars when the app is unfocused/hidden or Reduce Motion is enabled.
                starsLayer(time: 0, animate: false)
            }
        }
        .onAppear(perform: ensureStars)
    }

    @ViewBuilder
    private func starsLayer(time: TimeInterval, animate: Bool) -> some View {
        let drift = animate ? driftOffset(time: time) : .zero
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(animate ? twinkleOpacity(for: star, time: time) : star.baseOpacity)
                    .blur(radius: star.size > 2.2 ? 0.35 : 0.2)
                    .offset(x: star.x + drift.width, y: star.y + drift.height)
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private func ensureStars() {
        guard stars.isEmpty else { return }
        // Concentrate stars toward the upper half like the system Weather backgrounds.
        stars = (0..<140).map { i in
            Star(
                id: i,
                x: CGFloat.random(in: -260...260),
                y: CGFloat.random(in: -420...50),
                size: CGFloat.random(in: 1.0...2.8),
                baseOpacity: Double.random(in: 0.28...0.65),
                twinkleSpeed: Double.random(in: 1.0...3.2),
                delay: Double.random(in: 0...12)
            )
        }
    }
    
    private func twinkleOpacity(for star: Star, time: TimeInterval) -> Double {
        let t = time * star.twinkleSpeed + star.delay
        let slow = sin(t * 0.6) * 0.28
        let medium = sin(t * 1.6) * 0.16
        let micro = sin(t * 4.4) * 0.08
        let sparkle = (star.id % 6 == 0) ? max(0, sin(t * 3.6)) * 0.26 : 0.0
        let sizeBoost = star.size > 2.2 ? 0.14 : 0.0
        let value = star.baseOpacity + slow + medium + micro + sparkle + sizeBoost
        return min(max(value, 0.08), 1.0)
    }

    private func driftOffset(time: TimeInterval) -> CGSize {
        // Stronger, more readable drift across the sky.
        let x = sin(time * 0.08) * 40.0 + sin(time * 0.02) * 16.0
        let y = cos(time * 0.07) * 32.0 + cos(time * 0.018) * 12.0
        return CGSize(width: x, height: y)
    }
}

struct NightGlowEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 0.35

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.blue.opacity(0.12),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 220
                )
            )
            .frame(width: 420, height: 420)
            .offset(x: 180, y: -260)
            .opacity(pulse)
            .blur(radius: 40)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    pulse = 0.55
                }
            }
    }
}

struct ShootingStarsEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shootingStars: [ShootingStar] = []
    
    fileprivate struct ShootingStar: Identifiable {
        let id: UUID
        var x: CGFloat
        var y: CGFloat
        let angle: Double
        let length: CGFloat
        let speed: Double
        var opacity: Double
        var isActive: Bool
    }
    
    var body: some View {
        ZStack {
            ForEach(shootingStars) { star in
                if star.isActive {
                    ShootingStarView(star: star)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            scheduleShootingStar()
        }
    }
    
    private func scheduleShootingStar() {
        guard !reduceMotion else { return }
        
        // Random delay between shooting stars (5-15 seconds)
        let delay = Double.random(in: 5...15)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            createShootingStar()
            scheduleShootingStar() // Schedule the next one
        }
    }
    
    private func createShootingStar() {
        let newStar = ShootingStar(
            id: UUID(),
            x: CGFloat.random(in: -200...100),
            y: CGFloat.random(in: -350...(-200)),
            angle: Double.random(in: 25...65), // Diagonal angle
            length: CGFloat.random(in: 40...80),
            speed: Double.random(in: 0.6...1.2),
            opacity: 1.0,
            isActive: true
        )
        
        shootingStars.append(newStar)
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + newStar.speed + 0.5) {
            shootingStars.removeAll { $0.id == newStar.id }
        }
    }
}

fileprivate struct ShootingStarView: View {
    let star: ShootingStarsEffect.ShootingStar
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Tail
            LinearGradient(
                colors: [
                    Color.white.opacity(0.8),
                    Color.white.opacity(0.4),
                    Color.white.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: star.length, height: 1.5)
            .blur(radius: 0.8)
            
            // Bright head
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .blur(radius: 0.5)
        }
        .rotationEffect(.degrees(-star.angle))
        .opacity(opacity)
        .offset(x: star.x + offset * cos(star.angle * .pi / 180),
                y: star.y + offset * sin(star.angle * .pi / 180))
        .blendMode(.screen)
        .onAppear {
            // Fade in quickly
            withAnimation(.easeIn(duration: 0.1)) {
                opacity = 1.0
            }
            
            // Move across the sky
            withAnimation(.linear(duration: star.speed)) {
                offset = 400
            }
            
            // Fade out toward the end
            DispatchQueue.main.asyncAfter(deadline: .now() + star.speed * 0.7) {
                withAnimation(.easeOut(duration: star.speed * 0.3)) {
                    opacity = 0
                }
            }
        }
    }
}

struct LightningEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let intensity: Double

    @State private var flashOpacity: Double = 0
    @State private var timer: Timer?

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .opacity(flashOpacity)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                scheduleNextFlash()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }

    private func scheduleNextFlash() {
        let next = Double.random(in: 3.5...10.0)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: next, repeats: false) { _ in
            flash()
            scheduleNextFlash()
        }
    }

    private func flash() {
        // A quick double-flash feels most natural.
        withAnimation(.easeOut(duration: 0.08)) { flashOpacity = 0.18 * intensity }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.20)) { flashOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.06)) { flashOpacity = 0.12 * intensity }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeIn(duration: 0.20)) { flashOpacity = 0 }
            }
        }
    }
}

struct FogEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = -0.15

    var body: some View {
        ZStack {
            fogLayer(opacity: 0.08, blur: 40, y: -120, scale: 1.2, speed: 26, delay: 0)
            fogLayer(opacity: 0.06, blur: 55, y: -20,  scale: 1.45, speed: 32, delay: 3)
            fogLayer(opacity: 0.05, blur: 70, y: 120,  scale: 1.65, speed: 38, delay: 6)
        }
        .clipped() // Clip to prevent overflow affecting layout
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                drift = 0.15
            }
        }
    }

    private func fogLayer(opacity: Double, blur: CGFloat, y: CGFloat, scale: CGFloat, speed: Double, delay: Double) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(opacity),
                        Color.white.opacity(opacity * 0.5),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 250
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale)
            .offset(x: drift * 180, y: y)
            .blur(radius: blur)
            .animation(reduceMotion ? nil : .linear(duration: speed).repeatForever(autoreverses: true).delay(delay), value: drift)
    }
}


struct SunRaysEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var shimmer: Double = 0
    @State private var pulsePhase: Double = 0
    @State private var secondaryRotation: Double = 0

    var body: some View {
        ZStack {
            // Sun core with enhanced realistic glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.92).opacity(0.70), // Bright warm white
                            Color(red: 1.0, green: 0.92, blue: 0.65).opacity(0.48), // Soft yellow
                            Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.34), // Golden
                            Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.20), // Warm orange
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: 140, y: -260)
                .blur(radius: 10)
                .opacity(0.78 + pulsePhase * 0.05)

            // Inner corona - intense bright ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.55),
                            Color(red: 1.0, green: 0.85, blue: 0.50).opacity(0.30),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 200
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 140, y: -260)
                .blur(radius: 7)
                .opacity(0.65)
                .blendMode(.screen)

            // Primary rays - longer, more defined
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        RayShape(tapering: 0.6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.95, blue: 0.75).opacity(0.30),
                                        Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.22),
                                        Color(red: 1.0, green: 0.75, blue: 0.45).opacity(0.12),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 620, height: 12)
                            .blur(radius: 14)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(rotation))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.75),
                            Color.white.opacity(0.45),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 140,
                        endRadius: 580
                    )
                )
                .opacity(0.55)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Secondary rays - offset rotation for depth
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<16, id: \.self) { index in
                        RayShape(tapering: 0.75)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.90, blue: 0.70).opacity(0.20),
                                        Color(red: 1.0, green: 0.80, blue: 0.55).opacity(0.12),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 580, height: 8)
                            .blur(radius: 18)
                            .rotationEffect(.degrees(Double(index) * 22.5))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(secondaryRotation))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.65),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 160,
                        endRadius: 520
                    )
                )
                .opacity(0.38)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // God rays / volumetric light beams
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.12),
                                        Color(red: 1.0, green: 0.85, blue: 0.60).opacity(0.08),
                                        Color(red: 1.0, green: 0.75, blue: 0.50).opacity(0.04),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 720, height: 24)
                            .blur(radius: 28)
                            .rotationEffect(.degrees(Double(index) * 45))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(rotation * 0.3))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.30),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 180,
                        endRadius: 600
                    )
                )
                .opacity(0.28)
                .blendMode(.screen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Enhanced sunlit motes with depth
            if !reduceMotion {
                SunnyMotesEffect()
                    .opacity(0.35)
                    .blendMode(.screen)
            }

            // Improved warm shimmer with realistic light dispersion
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color(red: 1.0, green: 0.90, blue: 0.65).opacity(0.10),
                            Color(red: 1.0, green: 0.80, blue: 0.50).opacity(0.07),
                            Color(red: 1.0, green: 0.70, blue: 0.40).opacity(0.03),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.75, y: 0.15),
                        startRadius: 50,
                        endRadius: 550
                    )
                )
                .opacity(0.20 + shimmer * 0.10)
                .blendMode(.overlay)

            // Subtle atmospheric scattering effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.0),
                            Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.05),
                            Color(red: 0.85, green: 0.75, blue: 0.90).opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.30)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            
            // Slow, continuous ray rotation
            withAnimation(.linear(duration: 200).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Counter-rotation for depth effect
            withAnimation(.linear(duration: 280).repeatForever(autoreverses: false)) {
                secondaryRotation = -360
            }
            
            // Gentle pulsing shimmer
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                shimmer = 1
            }
            
            // Subtle pulse for sun core
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }
}

// Custom ray shape with natural tapering
struct RayShape: Shape {
    var tapering: Double = 0.7
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let height = rect.height
        let width = rect.width
        let taperPoint = width * tapering
        
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: taperPoint, y: 0))
        path.addLine(to: CGPoint(x: width, y: height / 2))
        path.addLine(to: CGPoint(x: taperPoint, y: height))
        path.closeSubpath()
        
        return path
    }
}

struct SunnyMotesEffect: View {
    @State private var motes: [(id: Int, x: CGFloat, y: CGFloat, size: CGFloat, speed: Double, delay: Double, horizontalDrift: CGFloat)] = []

    var body: some View {
        ZStack {
            ForEach(motes, id: \.id) { mote in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.95),
                                Color(red: 1.0, green: 0.90, blue: 0.70).opacity(0.65),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: mote.size / 2
                        )
                    )
                    .frame(width: mote.size, height: mote.size)
                    .blur(radius: 0.8)
                    .offset(x: mote.x, y: mote.y)
                    .modifier(EnhancedDriftUpModifier(
                        speed: mote.speed,
                        delay: mote.delay,
                        horizontalDrift: mote.horizontalDrift
                    ))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            motes = (0..<75).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -280...280),
                    y: CGFloat.random(in: -140...340),
                    size: CGFloat.random(in: 1.5...3.2),
                    speed: Double.random(in: 8.5...15.0),
                    delay: Double.random(in: 0...3.5),
                    horizontalDrift: CGFloat.random(in: -35...35)
                )
            }
        }
    }
}

private struct EnhancedDriftUpModifier: ViewModifier {
    let speed: Double
    let delay: Double
    let horizontalDrift: CGFloat
    @State private var verticalOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.6

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(x: horizontalOffset, y: verticalOffset)
            .onAppear {
                // Fade in and scale up
                withAnimation(.easeOut(duration: 1.5).delay(delay)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                // Vertical drift upward with fade out near the end
                withAnimation(.linear(duration: speed).delay(delay)) {
                    verticalOffset = -280
                }
                
                // Horizontal gentle sway
                withAnimation(
                    .easeInOut(duration: speed * 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    horizontalOffset = horizontalDrift
                }
                
                // Fade out as it reaches the top
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + speed * 0.75) {
                    withAnimation(.easeIn(duration: speed * 0.25)) {
                        opacity = 0.0
                    }
                }
            }
    }
}

// MARK: - Moon Effects for Night Time

struct MoonRaysEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appVisibility: AppVisibility
    @State private var rotation: Double = 0
    @State private var shimmer: Double = 0
    @State private var pulsePhase: Double = 0
    @State private var secondaryRotation: Double = 0

    var body: some View {
        let shouldAnimate = appVisibility.effectsActive && !reduceMotion
        Group {
            if shouldAnimate {
                TimelineView(.animation) { timeline in
                    moonBody(time: timeline.date.timeIntervalSinceReferenceDate, animate: true)
                }
            } else {
                moonBody(time: 0, animate: false)
            }
        }
    }

    @ViewBuilder
    private func moonBody(time: TimeInterval, animate: Bool) -> some View {
        let drift = animate ? moonDriftOffset(time: time) : .zero
        ZStack {
                // Moon core with soft silvery glow (reduced size)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.85), // Soft bluish-white
                                Color(red: 0.85, green: 0.90, blue: 0.98).opacity(0.65), // Cool silver
                                Color(red: 0.75, green: 0.82, blue: 0.95).opacity(0.48), // Pale blue
                                Color(red: 0.65, green: 0.75, blue: 0.92).opacity(0.28), // Deeper blue
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .offset(x: 140, y: -260)
                    .blur(radius: 10)
                    .opacity(0.75 + pulsePhase * 0.08)

                // Inner corona - soft moonlight ring (reduced size)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.92, green: 0.95, blue: 1.0).opacity(0.65),
                                Color(red: 0.80, green: 0.88, blue: 0.98).opacity(0.40),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: 140, y: -260)
                    .blur(radius: 8)
                    .opacity(0.75)
                    .blendMode(.screen)

                // Primary moonlight rays - softer and more ethereal than sun rays
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<12, id: \.self) { index in
                            RayShape(tapering: 0.6)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.35),
                                            Color(red: 0.75, green: 0.85, blue: 0.98).opacity(0.25),
                                            Color(red: 0.65, green: 0.78, blue: 0.95).opacity(0.15),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 700, height: 12)
                                .blur(radius: 14)
                                .rotationEffect(.degrees(Double(index) * 30))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                    .rotationEffect(.degrees(rotation))
                    .mask(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.5),
                                Color.clear
                            ],
                            center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                            y: (-260 + geometry.size.height / 2) / geometry.size.height),
                            startRadius: 140,
                            endRadius: 580
                        )
                    )
                    .opacity(0.65)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Secondary rays - offset rotation for depth
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<16, id: \.self) { index in
                            RayShape(tapering: 0.75)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.80, green: 0.88, blue: 1.0).opacity(0.22),
                                            Color(red: 0.70, green: 0.80, blue: 0.98).opacity(0.14),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 650, height: 8)
                                .blur(radius: 18)
                                .rotationEffect(.degrees(Double(index) * 22.5))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                    .rotationEffect(.degrees(secondaryRotation))
                    .mask(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.75),
                                Color.clear
                            ],
                            center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                            y: (-260 + geometry.size.height / 2) / geometry.size.height),
                            startRadius: 160,
                            endRadius: 520
                        )
                    )
                    .opacity(0.45)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Moonbeams - mystical light beams
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<8, id: \.self) { index in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.88, green: 0.92, blue: 1.0).opacity(0.18),
                                            Color(red: 0.78, green: 0.85, blue: 0.98).opacity(0.12),
                                            Color(red: 0.68, green: 0.78, blue: 0.95).opacity(0.06),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 800, height: 24)
                                .blur(radius: 28)
                                .rotationEffect(.degrees(Double(index) * 45))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                    .rotationEffect(.degrees(rotation * 0.3))
                    .mask(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.35),
                                Color.clear
                            ],
                            center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                            y: (-260 + geometry.size.height / 2) / geometry.size.height),
                            startRadius: 180,
                            endRadius: 600
                        )
                    )
                    .opacity(0.4)
                    .blendMode(.screen)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Enhanced moonlight motes with depth
                if !reduceMotion {
                    MoonlightMotesEffect()
                        .opacity(0.65)
                        .blendMode(.screen)
                }

                // Cool moonlight shimmer
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                Color(red: 0.85, green: 0.90, blue: 1.0).opacity(0.12),
                                Color(red: 0.75, green: 0.85, blue: 0.98).opacity(0.08),
                                Color(red: 0.65, green: 0.80, blue: 0.95).opacity(0.04),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.75, y: 0.15),
                            startRadius: 50,
                            endRadius: 550
                        )
                    )
                    .opacity(0.25 + shimmer * 0.15)
                    .blendMode(.overlay)

                // Atmospheric moonlight scattering effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.0),
                                Color(red: 0.80, green: 0.88, blue: 0.98).opacity(0.06),
                                Color(red: 0.70, green: 0.82, blue: 0.95).opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.35)
                    .blendMode(.screen)
            }
            .offset(drift)
            .allowsHitTesting(false)
        .onAppear {
            guard appVisibility.effectsActive, !reduceMotion else { return }

            // Slower rotation for mysterious moon effect
            withAnimation(.linear(duration: 280).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            // Counter-rotation for depth effect
            withAnimation(.linear(duration: 380).repeatForever(autoreverses: false)) {
                secondaryRotation = -360
            }

            // Gentle pulsing shimmer
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                shimmer = 1
            }

            // Subtle pulse for moon core
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }


    private func moonDriftOffset(time: TimeInterval) -> CGSize {
        // Dramatic drift for a visibly moving moon.
        let x = sin(time * 0.055) * 48.0 + sin(time * 0.018) * 22.0
        let y = cos(time * 0.05) * 38.0 + cos(time * 0.016) * 18.0
        return CGSize(width: x, height: y)
    }
}


struct MoonlightMotesEffect: View {
    @State private var motes: [(id: Int, x: CGFloat, y: CGFloat, size: CGFloat, speed: Double, delay: Double, horizontalDrift: CGFloat)] = []

    var body: some View {
        ZStack {
            ForEach(motes, id: \.id) { mote in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.90),
                                Color(red: 0.80, green: 0.88, blue: 0.98).opacity(0.60),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: mote.size / 2
                        )
                    )
                    .frame(width: mote.size, height: mote.size)
                    .blur(radius: 1.0)
                    .offset(x: mote.x, y: mote.y)
                    .modifier(MoonlightDriftModifier(
                        speed: mote.speed,
                        delay: mote.delay,
                        horizontalDrift: mote.horizontalDrift
                    ))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            motes = (0..<60).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -280...280),
                    y: CGFloat.random(in: -140...340),
                    size: CGFloat.random(in: 1.2...2.8),
                    speed: Double.random(in: 10.0...18.0),
                    delay: Double.random(in: 0...4.0),
                    horizontalDrift: CGFloat.random(in: -30...30)
                )
            }
        }
    }
}

private struct MoonlightDriftModifier: ViewModifier {
    let speed: Double
    let delay: Double
    let horizontalDrift: CGFloat
    @State private var verticalOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.5

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(x: horizontalOffset, y: verticalOffset)
            .onAppear {
                // Fade in and scale up
                withAnimation(.easeOut(duration: 2.0).delay(delay)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                // Vertical drift upward with fade out near the end
                withAnimation(.linear(duration: speed).delay(delay)) {
                    verticalOffset = -280
                }
                
                // Horizontal gentle sway - more pronounced for moon
                withAnimation(
                    .easeInOut(duration: speed * 0.7)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    horizontalOffset = horizontalDrift
                }
                
                // Fade out as it reaches the top
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + speed * 0.75) {
                    withAnimation(.easeIn(duration: speed * 0.25)) {
                        opacity = 0.0
                    }
                }
            }
    }
}

struct RainEffect: View {
    @State private var drops: [(id: Int, x: CGFloat, delay: Double, speed: Double)] = []
    
    var body: some View {
        ZStack {
            // Rain drops with individual animations
            ForEach(drops, id: \.id) { drop in
                RainDrop(delay: drop.delay, speed: drop.speed)
                    .offset(x: drop.x)
            }
            
            // Subtle water ripple effect at bottom
            WaterRippleEffect()
        }
        .allowsHitTesting(false)
        .onAppear {
            drops = (0..<50).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -300...300),
                    delay: Double(i) * 0.05,
                    speed: Double.random(in: 0.6...1.0)
                )
            }
        }
    }
}

struct RainDrop: View {
    let delay: Double
    let speed: Double
    @State private var yOffset: CGFloat = -400
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2, height: CGFloat.random(in: 25...45))
            .offset(y: yOffset)
            .blur(radius: 0.5)
            .onAppear {
                withAnimation(
                    .linear(duration: speed)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    yOffset = 700
                }
            }
    }
}

struct WaterRippleEffect: View {
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0.3
    
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(rippleOpacity), lineWidth: 2)
            .frame(width: 200, height: 200)
            .scaleEffect(rippleScale)
            .offset(y: 300)
            .blur(radius: 3)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2)
                    .repeatForever(autoreverses: false)
                ) {
                    rippleScale = 1.5
                    rippleOpacity = 0
                }
            }
    }
}

struct DrizzleEffect: View {
    @State private var drops: [(id: Int, x: CGFloat, delay: Double, speed: Double)] = []
    
    var body: some View {
        ZStack {
            // Drizzle drops with individual animations - fewer and lighter than rain
            ForEach(drops, id: \.id) { drop in
                DrizzleDrop(delay: drop.delay, speed: drop.speed)
                    .offset(x: drop.x)
            }
            
            // Very subtle mist effect at bottom
            DrizzleMistEffect()
        }
        .allowsHitTesting(false)
        .onAppear {
            // Fewer drops than rain (30 vs 50) for lighter effect
            drops = (0..<30).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -300...300),
                    delay: Double(i) * 0.08, // Slightly more spaced out
                    speed: Double.random(in: 0.8...1.4) // Slower than rain
                )
            }
        }
    }
}

struct DrizzleDrop: View {
    let delay: Double
    let speed: Double
    @State private var yOffset: CGFloat = -400
    @State private var opacity: Double = 0.3
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1.5, height: CGFloat.random(in: 15...30)) // Smaller than rain
            .offset(y: yOffset)
            .blur(radius: 0.8) // More blur for softer appearance
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .linear(duration: speed)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    yOffset = 700
                }
                
                // Subtle opacity variation to simulate lighter rain
                withAnimation(
                    .easeInOut(duration: speed * 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    opacity = Double.random(in: 0.2...0.5)
                }
            }
    }
}

struct DrizzleMistEffect: View {
    @State private var mistOpacity: Double = 0.0
    @State private var mistOffset: CGFloat = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            // Subtle mist effect at the bottom
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(mistOpacity * 0.08),
                            Color.white.opacity(mistOpacity * 0.12),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 150)
                .blur(radius: 20)
                .offset(y: mistOffset)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                mistOpacity = 1.0
            }
            
            withAnimation(
                .easeInOut(duration: 6)
                .repeatForever(autoreverses: true)
            ) {
                mistOffset = -20
            }
        }
    }
}

struct SnowEffect: View {
    @State private var snowflakes: [(id: Int, x: CGFloat, size: CGFloat, delay: Double, speed: Double, drift: CGFloat)] = []
    
    var body: some View {
        ZStack {
            ForEach(snowflakes, id: \.id) { flake in
                Snowflake(
                    size: flake.size,
                    delay: flake.delay,
                    speed: flake.speed,
                    drift: flake.drift
                )
                .offset(x: flake.x)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            snowflakes = (0..<120).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -300...300),
                    size: CGFloat.random(in: 3...10),
                    delay: Double(i) * 0.05,
                    speed: Double.random(in: 4...8),
                    drift: CGFloat.random(in: -30...30)
                )
            }
        }
    }
}

struct Snowflake: View {
    let size: CGFloat
    let delay: Double
    let speed: Double
    let drift: CGFloat
    @State private var yOffset: CGFloat = -400
    @State private var xDrift: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Snowflake shape
            Circle()
                .fill(Color.white.opacity(0.8))
            
            // Add sparkle effect for larger flakes
            if size > 7 {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.3, height: size * 0.3)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.4), radius: size * 0.5)
        .rotationEffect(.degrees(rotation))
        .offset(x: xDrift, y: yOffset)
        .onAppear {
            startSnowfallAnimation()
            
            withAnimation(
                .easeInOut(duration: speed / 2)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                xDrift = drift
            }
            
            withAnimation(
                .linear(duration: speed * 0.7)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                rotation = 360
            }
        }
    }
    
    private func startSnowfallAnimation() {
        // Reset to top
        yOffset = -400
        
        // Animate down after initial delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateSnowfall()
        }
    }
    
    private func animateSnowfall() {
        withAnimation(.linear(duration: speed)) {
            yOffset = 700
        }
        
        // After animation completes, reset and start again
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            startSnowfallAnimation()
        }
    }
}

struct CloudEffect: View {
    @State private var clouds: [(id: Int, yPos: CGFloat, width: CGFloat, height: CGFloat, delay: Double, speed: Double)] = []
    
    var body: some View {
        ZStack {
            ForEach(clouds, id: \.id) { cloud in
                AnimatedCloud(
                    width: cloud.width,
                    height: cloud.height,
                    delay: cloud.delay,
                    speed: cloud.speed
                )
                .offset(y: cloud.yPos)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            clouds = (0..<8).map { i in
                (
                    id: i,
                    yPos: CGFloat.random(in: -250...150),
                    width: CGFloat.random(in: 100...180),
                    height: CGFloat.random(in: 50...80),
                    delay: Double(i) * 3,
                    speed: Double.random(in: 40...70)
                )
            }
        }
    }
}

struct AnimatedCloud: View {
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let speed: Double
    @State private var xOffset: CGFloat = -400
    @State private var scaleEffect: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Main cloud body
            Ellipse()
                .fill(Color.white.opacity(0.25))
                .frame(width: width, height: height)
            
            // Cloud puffs for more realistic shape
            Ellipse()
                .fill(Color.white.opacity(0.2))
                .frame(width: width * 0.6, height: height * 0.7)
                .offset(x: -width * 0.2, y: -height * 0.1)
            
            Ellipse()
                .fill(Color.white.opacity(0.2))
                .frame(width: width * 0.5, height: height * 0.6)
                .offset(x: width * 0.25, y: height * 0.1)
        }
        .blur(radius: 20)
        .scaleEffect(scaleEffect)
        .offset(x: xOffset)
        .onAppear {
            withAnimation(
                .linear(duration: speed)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                xOffset = 900
            }
            
            withAnimation(
                .easeInOut(duration: 5)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                scaleEffect = 1.1
            }
        }
    }
}

// MARK: - Lens Flare (Sunny Day)

struct LensFlareEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Origin of the light source relative to the view's center
    // Matches the sun position used by SunRaysEffect (approximately top-right)
    var originOffset: CGPoint = CGPoint(x: 140, y: -260)
    var intensity: Double = 1.0 // 0.0 - 1.5 recommended

    @State private var shimmer: Double = 0
    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let sun = CGPoint(x: center.x + originOffset.x, y: center.y + originOffset.y)

            // Direction from sun through the center to the opposite side
            let dir = CGVector(dx: center.x - sun.x, dy: center.y - sun.y)
            let length = max(1.0, hypot(dir.dx, dir.dy))
            let ux = dir.dx / length
            let uy = dir.dy / length

            ZStack {
                // Anamorphic streak near the sun
                streak(at: sun, angle: atan2(uy, ux))
                    .opacity(0.25 * intensity + 0.15 * shimmer)
                    .blendMode(.screen)

                // Flare artifacts ("ghosts") along the line from sun through center
                // Distances are along the direction vector; sizes/opacities tuned for a subtle effect
                flareGhost(distance: 160, baseSize: 90,  baseOpacity: 0.22, center: center, sun: sun, ux: ux, uy: uy)
                flareGhost(distance: 300, baseSize: 70,  baseOpacity: 0.18, center: center, sun: sun, ux: ux, uy: uy)
                flareGhost(distance: 460, baseSize: 52,  baseOpacity: 0.16, center: center, sun: sun, ux: ux, uy: uy)
                flareGhost(distance: 620, baseSize: 36,  baseOpacity: 0.14, center: center, sun: sun, ux: ux, uy: uy)
                flareGhost(distance: 780, baseSize: 26,  baseOpacity: 0.12, center: center, sun: sun, ux: ux, uy: uy)

                // Tiny sparkles closer to the sun for liveliness
                sparkle(at: point(from: sun, ux: ux, uy: uy, distance: 110), size: 18)
                    .opacity(0.25 + 0.25 * shimmer)
                    .blendMode(.screen)
                sparkle(at: point(from: sun, ux: ux, uy: uy, distance: 220), size: 14)
                    .opacity(0.18 + 0.22 * shimmer)
                    .blendMode(.screen)
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            // Gentle shimmer and micro drift to keep it alive
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                shimmer = 1
            }
            withAnimation(.easeInOut(duration: 14.0).repeatForever(autoreverses: true)) {
                drift = 1.0
            }
        }
    }

    private func point(from sun: CGPoint, ux: CGFloat, uy: CGFloat, distance: CGFloat) -> CGPoint {
        // Drift slightly along the direction to avoid a static feel
        let d = distance + drift
        return CGPoint(x: sun.x + ux * d, y: sun.y + uy * d)
    }

    @ViewBuilder
    private func flareGhost(distance: CGFloat, baseSize: CGFloat, baseOpacity: Double, center: CGPoint, sun: CGPoint, ux: CGFloat, uy: CGFloat) -> some View {
        let p = point(from: sun, ux: ux, uy: uy, distance: distance)
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.85),
                        Color(red: 1.0, green: 0.90, blue: 0.65).opacity(0.45),
                        Color(red: 1.0, green: 0.75, blue: 0.45).opacity(0.25),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: baseSize * 0.65
                )
            )
            .frame(width: baseSize, height: baseSize)
            .blur(radius: 8)
            .position(p)
            .opacity((baseOpacity + 0.10 * shimmer) * intensity)
            .blendMode(.screen)
    }

    @ViewBuilder
    private func sparkle(at point: CGPoint, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.25, height: size * 0.25)
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .frame(width: size, height: size)
                .blur(radius: 0.5)
        }
        .position(point)
    }

    @ViewBuilder
    private func streak(at origin: CGPoint, angle: CGFloat) -> some View {
        // A subtle anamorphic streak aligned with the light direction
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.35),
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.35),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 520, height: 6)
            .blur(radius: 8)
            .rotationEffect(.radians(Double(angle)))
            .position(origin)
    }
}
