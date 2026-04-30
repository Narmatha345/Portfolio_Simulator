import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import 'src/providers/portfolio_provider.dart';
import 'src/providers/sip_portfolio_provider.dart';
import 'src/providers/swp_portfolio_provider.dart';
import 'src/help/help_provider.dart'; // ✅ FIX: Added missing HelpProvider import

// Screens
import 'src/screens/stock_price_screen.dart';
import 'src/screens/stock_sip_screen.dart';
import 'src/screens/stock_swp_screen.dart';
import 'src/screens/yahoo_stock_price_screen.dart';
import 'src/screens/weekly_stock_price_screen.dart';
import 'src/screens/lumpsum_sip_compare_screen.dart'; 
import 'src/screens/networth_estimator_screen.dart';
import 'src/screens/networth_estimator_copy_screen.dart'; 
import 'src/screens/networth_gold_screen.dart'; 

// Widgets & Help
import 'src/help/help_drawer.dart'; // ✅ FIX: Added HelpDrawer import
import 'src/widgets/help_button.dart'; // ✅ FIX: Added HelpButton import

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => SipPortfolioProvider()),
        ChangeNotifierProvider(create: (_) => SwpPortfolioProvider()),
        ChangeNotifierProvider(create: (_) => HelpProvider()), 
      ],
      child: const MaterialApp(
        home: MainNavigationWrapper(), 
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const StockPriceScreen(),
    const StockSipScreen(),
    const StockSwpScreen(),
    const YahooStockPriceScreen(),
    const WeeklyStockPriceScreen(),
    const LumpsumSipCompareScreen(), 
    const NetworthEstimatorScreen(), 
    const NetworthEstimatorCopyScreen(), 
    const NetworthGoldScreen(), 
  ];

  final List<String> _titles = [
    "Lumpsum Simulator",
    "SIP (Stocks)",
    "SWP (Stocks)",
    "Yahoo Finance",
    "Weekly High/Low",
    "Lumpsum vs SIP Compare", 
    "Networth Estimator", 
    "Networth Estimator Copy", 
    "Networth Gold", 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        // ✅ Added Help Button in AppBar to trigger the Help Drawer
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: HelpButton(topic: 'getting-started'),
          ),
        ],
      ),
      
      // ✅ Added HelpDrawer to the Scaffold so it can be opened
      endDrawer: const HelpDrawer(),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1F2937)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock Simulator', 
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Menu Options', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            
            ListTile(
              leading: const Icon(Icons.show_chart, color: Color(0xFF6366F1)),
              title: const Text('Lumpsum Simulator'),
              selected: _selectedIndex == 0,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFFEC4899)),
              title: const Text('SIP (Stocks)'),
              selected: _selectedIndex == 1,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF10B981)),
              title: const Text('SWP (Stocks)'),
              selected: _selectedIndex == 2,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.public, color: Color(0xFF8B5CF6)),
              title: const Text('Yahoo Finance'),
              selected: _selectedIndex == 3,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.assessment_outlined, color: Colors.orange),
              title: const Text('Weekly High/Low'),
              selected: _selectedIndex == 4,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.compare_arrows, color: Colors.blueAccent),
              title: const Text('Compare Lumpsum vs SIP'),
              selected: _selectedIndex == 5,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.green),
              title: const Text('Networth Estimator'),
              selected: _selectedIndex == 6,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 6);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.teal),
              title: const Text('Networth Estimator Copy'),
              selected: _selectedIndex == 7,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 7);
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.purple),
              title: const Text('Networth Gold View'),
              selected: _selectedIndex == 8,
              selectedTileColor: Colors.grey[200],
              onTap: () {
                setState(() => _selectedIndex = 8);
                Navigator.pop(context);
              },
            ),

            
          ],
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}