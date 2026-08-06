//
//  DashboardView.swift
//  ResourceRunner
//
//  Created by zipkero on 8/2/26.
//

import SwiftUI

/// M1 대시보드 팝오버 셸.
/// 완성된 자원 카드는 이후 Task에서 채워지며, 여기서는 팝오버 콘텐츠 경계만 담당합니다.
struct DashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ResourceRunner")
                .font(.headline)
            Text("대시보드 준비 중")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 280, height: 200, alignment: .topLeading)
    }
}

#Preview {
    DashboardView()
}
