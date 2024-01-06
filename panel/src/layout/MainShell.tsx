import { useEventListener } from 'usehooks-ts';
import MainRouter from "./MainRouter";
import { useExpireAuthData } from '../hooks/auth';
import { Header } from './Header';
import { ServerSidebar } from './ServerSidebar/ServerSidebar';
import { PlayerlistSidebar } from './PlayerlistSidebar/PlayerlistSidebar';
import MainSheets from './MainSheets';
import WarningBar from './WarningBar';
import ConfirmDialog from '@/components/ConfirmDialog';
import PromptDialog from '@/components/PromptDialog';
import TxToaster from '@/components/TxToaster';
import AccountDialog from '@/components/AccountDialog';
import { useOpenAccountModal } from '@/hooks/dialogs';
import PlayerModal from './PlayerModal/PlayerModal';
import { useOpenPlayerModal } from '@/hooks/playerModal';
import { navigate as setLocation } from 'wouter/use-location';
import MainSocket from './MainSocket';
import { TooltipProvider } from '@/components/ui/tooltip';
import { useToggleTheme } from '@/hooks/useTheme';
import BreakpointDebugger from '@/components/BreakpointDebugger';


export default function MainShell() {
    const expireSession = useExpireAuthData();
    const openAccountModal = useOpenAccountModal();
    const openPlayerModal = useOpenPlayerModal();
    const toggleTheme = useToggleTheme();

    //Listener for messages from child iframes (legacy routes)
    useEventListener('message', (e: MessageEventFromIframe) => {
        if (e.data.type === 'logoutNotice') {
            expireSession('child iframe', 'got logoutNotice');
        } else if (e.data.type === 'openAccountModal') {
            openAccountModal();
        } else if (e.data.type === 'openPlayerModal') {
            openPlayerModal(e.data.ref);
        } else if (e.data.type === 'navigateToPage') {
            setLocation(e.data.href);
        }
    });

    //Listens to hotkeys - DEBUG only for now
    //NOTE: WILL NOT WORK IF THE FOCUS IS ON THE IFRAME
    useEventListener('keydown', (e: KeyboardEvent) => {
        if (!window.txConsts.showAdvanced) return;
        if (e.ctrlKey && e.key === 'k') {
            const el = document.getElementById('playerlistFilter');
            if (el) {
                el.focus();
                e.preventDefault();
            }
        } else if (e.ctrlKey && e.shiftKey && e.key.toLowerCase() === 'l') {
            toggleTheme();
            e.preventDefault();
        }
    });

    return <>
        <TooltipProvider delayDuration={300} disableHoverableContent={true}>
            <Header />
            <div className="md:px-3 min-h-full pt-2 md:py-4 w-full max-w-[1920px] mx-auto flex flex-row gap-4">
                <ServerSidebar />
                <main className="flex flex-1 min-h-[calc(100vh-4rem-1px)] md:min-h-[calc(100vh-5.5rem-1px)]">
                    <MainRouter />
                </main>
                {window.txConsts.isWebInterface && <PlayerlistSidebar />}
            </div>

            <MainSheets />
            <WarningBar />
            <ConfirmDialog />
            <PromptDialog />
            <TxToaster />
            <AccountDialog />
            <PlayerModal />
            <MainSocket />
            {/* <BreakpointDebugger /> */}
        </TooltipProvider>
    </>;
}
