"""Regression contracts for Flutter analyzer CI gate and source compatibility."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class AnalyzerHotfixRegression(unittest.TestCase):
    def test_both_ci_jobs_nonfatal_advisories_but_errors_still_fatal(self):
        for name in ('windows.yml','android.yml'):
            wf=(ROOT/'.github/workflows'/name).read_text(encoding='utf8')
            self.assertEqual(wf.count('flutter analyze --no-fatal-infos --no-fatal-warnings'),1)
            self.assertIn('flutter test', wf)
            self.assertIn('flutter build ',wf)
            self.assertLess(wf.index('flutter analyze'),wf.index('flutter test'))
            self.assertLess(wf.index('flutter test'),wf.index('flutter build '))
    def test_deprecated_cache_extent_removed(self):
        source=(ROOT/'lib/ui/vybe_mobile_app.dart').read_text(encoding='utf8')
        self.assertNotIn('scrollCacheExtent:',source)
        self.assertNotIn('cacheExtent:',source)
        self.assertIn('itemExtent: 70',source)
        self.assertNotIn('      cacheExtent: 450,',source)
    def test_unused_online_route_removed_but_browser_retained(self):
        source=(ROOT/'lib/ui/vybe_mobile_app.dart').read_text(encoding='utf8')
        self.assertNotIn('void _openWebsite(',source)
        self.assertIn('class _ApprovedMusicBrowser extends StatefulWidget',source)
        self.assertIn("key: ValueKey('online-${t.id}')",source)
    def test_windows_functionality_retained(self):
        desktop=(ROOT/'lib/ui/vybe_app.dart').read_text(encoding='utf8')
        self.assertIn('interactive: true',desktop)
        self.assertIn('thumbVisibility: true',desktop)
        self.assertIn('class _VybeTitlebar extends StatelessWidget',desktop)
if __name__=='__main__': unittest.main()
