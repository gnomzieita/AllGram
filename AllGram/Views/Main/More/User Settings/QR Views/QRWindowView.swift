//
//  QRWindowView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 23.12.2021.
//

import SwiftUI

struct QRWindowView: View {
    
    let cornerLineWidth: CGFloat = 3
    let cornerColor: Color = .green
    
    let lineLineWidth: CGFloat = 1
    let lineColor: Color = .red
    
    let size: CGSize
    
    var body: some View {
        VStack(spacing: 0) {
            blurRect
            HStack(spacing: 0) {
                blurRect
                ZStack {
                    QRWindowCornersShape()
                        .stroke(cornerColor, lineWidth: cornerLineWidth)
                    QRWindowLineShape()
                        .stroke(lineColor, lineWidth: lineLineWidth)
                }
                .frame(width: size.width * 0.7, height:  size.width * 0.5)
                blurRect
            }
            .frame(height: size.width * 0.5)
            blurRect
        }
        .ignoresSafeArea()
    }
    
    private var blurRect: some View {
        Rectangle().foregroundColor(.black.opacity(0.6))
    }
    
    // MARK: Custom Shapes
    
    struct QRWindowCornersShape: Shape {
        
        let offset: CGFloat = 1
        
        func path(in rect: CGRect) -> Path {
            let size = rect.size
            let minLength = min(size.width, size.height) / 5 + offset
            var path = Path()
            // Top left
            path.move(to: CGPoint(x: offset, y: minLength))
            path.addLine(to: CGPoint(x: offset, y: offset))
            path.addLine(to: CGPoint(x: minLength, y: offset))
            // Top right
            path.move(to: CGPoint(x: size.width - offset, y: minLength))
            path.addLine(to: CGPoint(x: size.width - offset, y: offset))
            path.addLine(to: CGPoint(x: size.width - minLength, y: offset))
            // Bot left
            path.move(to: CGPoint(x: offset, y: size.height - minLength))
            path.addLine(to: CGPoint(x: offset, y: size.height - offset))
            path.addLine(to: CGPoint(x: minLength, y: size.height - offset))
            // Bot left
            path.move(to: CGPoint(x: size.width - offset, y: size.height - minLength))
            path.addLine(to: CGPoint(x: size.width - offset, y: size.height - offset))
            path.addLine(to: CGPoint(x: size.width - minLength, y: size.height - offset))
            return path
        }
        
    }
    
    struct QRWindowLineShape: Shape {
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.size.height / 2))
            path.addLine(to: CGPoint(x: rect.size.width, y: rect.size.height / 2))
            return path
        }
        
    }
    
}

struct QRWindowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GeometryReader { geometry in
                QRWindowView(size: geometry.size)
                    .colorScheme(.dark)
            }
            GeometryReader { geometry in
                QRWindowView(size: geometry.size)
                    .colorScheme(.light)
            }
        }
        
    }
}
