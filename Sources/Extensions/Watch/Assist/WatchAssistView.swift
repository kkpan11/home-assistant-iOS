import Shared
import SwiftUI

struct WatchAssistView: View {
    @StateObject private var viewModel: WatchAssistViewModel
    @State private var isInitialAppearance = true
    private let progressViewId = "progressViewId"

    init(
        viewModel: WatchAssistViewModel
    ) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Button(action: {
                viewModel.assist()
            }, label: {
                ZStack(alignment: .bottom) {
                    micButton
                    chatList
                    stateView
                    inlineLoading
                }
                .modify({ view in
                    if #available(watchOS 10, *) {
                        view.toolbar(content: {
                            ToolbarItem(placement: .topBarTrailing) {
                                volumeButton
                            }
                        })
                    } else {
                        view.toolbar(content: {
                            ToolbarItem {
                                volumeButton
                            }
                        })
                    }
                })
            })
            .buttonStyle(.plain)
            .modify { view in
                if #available(watchOS 11, *) {
                    view.handGestureShortcut(.primaryAction)
                } else {
                    view
                }
            }
        }
        .animation(.easeInOut, value: viewModel.state)
        .onAppear {
            // Avoid re-trigger when coming back from audio volume screen
            if isInitialAppearance {
                isInitialAppearance = false
                viewModel.initialRoutine()
            }
        }
        .onDisappear {
            viewModel.endRoutine()
        }
        .onChange(of: viewModel.state) { newValue in
            // TODO: On watchOS 10 this can be replaced by '.sensoryFeedback' modifier
            let currentDevice = WKInterfaceDevice.current()
            switch newValue {
            case .recording:
                currentDevice.play(.start)
            case .waitingForPipelineResponse:
                currentDevice.play(.start)
                viewModel.startPingPong()
            case .idle:
                viewModel.stopPingPong()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
            viewModel.initialRoutine()
        }
    }

    private var volumeButton: some View {
        NavigationLink(destination: VolumeView()) {
            Image(systemName: "speaker.wave.2.fill")
        }
    }

    @ViewBuilder
    private var stateView: some View {
        micRecording
            .opacity(viewModel.state == .recording ? 1 : 0)
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(.init(floatLiteral: 2))
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modify {
                if #available(watchOS 10, *) {
                    $0.background(.regularMaterial)
                } else {
                    $0.background(.black.opacity(0.5))
                }
            }
            .opacity(viewModel.state == .loading ? 1 : 0)
    }

    @ViewBuilder
    private var micButton: some View {
        if ![.loading, .recording].contains(viewModel.state), !viewModel.showChatLoader {
            HStack(spacing: Spaces.one) {
                if viewModel.assistService.deviceReachable {
                    Text(verbatim: L10n.Assist.Watch.MicButton.title)
                    Image(systemName: "mic.fill")
                } else {
                    Image(systemName: "iphone.slash")
                        .foregroundStyle(.red)
                        .padding(.trailing)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.gray)
            .offset(y: 22)
        }
    }

    @ViewBuilder
    private var inlineLoading: some View {
        if ![.loading, .recording].contains(viewModel.state) {
            if viewModel.showChatLoader {
                micButtonProgressView
            }
        }
    }

    private var micButtonProgressView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(.init(floatLiteral: 1.5))
            .frame(maxWidth: .infinity, alignment: .center)
            .progressViewStyle(.linear)
            .frame(height: 40)
            .padding(Spaces.half)
            .modify {
                if #available(watchOS 10, *) {
                    $0.background(.regularMaterial)
                } else {
                    $0.background(.black.opacity(0.3))
                }
            }
            .clipShape(Circle())
    }

    @ViewBuilder
    private var micRecording: some View {
        Button(action: {
            viewModel.assist()
        }, label: {
            VStack(spacing: .zero) {
                if #available(watchOS 10.0, *) {
                    Image(systemSymbol: .waveformCircleFill)
                        .font(.system(size: 80))
                        .symbolEffect(
                            .variableColor.cumulative.dimInactiveLayers.nonReversing,
                            options: .repeating,
                            value: viewModel.state
                        )
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.haPrimary)
                } else {
                    Image(systemSymbol: .waveformCircleFill)
                        .font(.system(size: 50))
                }
                Text(verbatim: L10n.Watch.Assist.Button.Recording.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                Text(verbatim: L10n.Watch.Assist.Button.SendRequest.title)
                    .font(.footnote.bold())
                    .padding()
            }
        })
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modify {
            if #available(watchOS 10, *) {
                $0.background(.regularMaterial)
            } else {
                $0.background(.black.opacity(0.5))
            }
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Using LazyVStack instead of List to avoid List minimum row height
                LazyVStack(spacing: Spaces.one) {
                    ForEach(viewModel.chatItems, id: \.id) { item in
                        ChatBubbleView(item: item)
                    }
                    if viewModel.chatItems.isEmpty {
                        emptyState
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
                .animation(.easeInOut, value: viewModel.chatItems)
                .onChange(of: viewModel.chatItems) { _ in
                    if let lastItem = viewModel.chatItems.last {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Image(uiImage: Asset.casitaDark.image)
                .resizable()
                .frame(
                    width: 70,
                    height: 70,
                    alignment: .center
                )
                .aspectRatio(contentMode: .fit)
                .opacity(0.5)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}
