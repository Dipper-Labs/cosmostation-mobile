//
//  StepRepayCdpAmountViewController.swift
//  Cosmostation
//
//  Created by 정용주 on 2020/04/01.
//  Copyright © 2020 wannabit. All rights reserved.
//

import UIKit
import Alamofire

class StepRepayCdpAmountViewController: BaseViewController, UITextFieldDelegate, SBCardPopupDelegate{
    
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var loadingImg: LoadingImageView!
    
    @IBOutlet weak var pDenomImg: UIImageView!
    @IBOutlet weak var pDenomLabel: UILabel!
    @IBOutlet weak var pAmountInput: AmountInputTextField!
    @IBOutlet weak var btnPAmountClear: UIButton!
    @IBOutlet weak var pParticalTitle: UILabel!
    @IBOutlet weak var pParticalMinLabel: UILabel!
    @IBOutlet weak var pParticalDashLabel: UILabel!
    @IBOutlet weak var pParticalMaxLabel: UILabel!
    @IBOutlet weak var pParticalDenom: UILabel!
    @IBOutlet weak var pDisablePartical: UILabel!
    @IBOutlet weak var pAllTitle: UILabel!
    @IBOutlet weak var pAllLabel: UILabel!
    @IBOutlet weak var pAllDenom: UILabel!
    @IBOutlet weak var pDisableAll: UILabel!

    @IBOutlet weak var beforeSafeTxt: UILabel!
    @IBOutlet weak var beforeSafeRate: UILabel!
    @IBOutlet weak var afterSafeTxt: UILabel!
    @IBOutlet weak var afterSafeRate: UILabel!
    
    var pageHolderVC: StepGenTxViewController!
    
    var cDenom: String = ""
    var pDenom: String = ""
    var cDpDecimal:Int16 = 6
    var pDpDecimal:Int16 = 6
    var mMarketID: String = ""
    
    var cdpParam:CdpParam?
    var cParam: CdpParam.CollateralParam?
    var mMyCdps: CdpOwen?
    var mMyCdpDeposit: CdpDeposits?
    var mPrice: KavaTokenPrice?
    
    var currentPrice: NSDecimalNumber = NSDecimalNumber.zero
    var beforeLiquidationPrice: NSDecimalNumber = NSDecimalNumber.zero
    var afterLiquidationPrice: NSDecimalNumber = NSDecimalNumber.zero
    var beforeRiskRate: NSDecimalNumber = NSDecimalNumber.zero
    var afterRiskRate: NSDecimalNumber = NSDecimalNumber.zero
    
    var pMinAmount: NSDecimalNumber = NSDecimalNumber.zero
    var pMaxAmount: NSDecimalNumber = NSDecimalNumber.zero
    var pAllAmount: NSDecimalNumber = NSDecimalNumber.zero
    var toPAmount: NSDecimalNumber = NSDecimalNumber.zero
    var pAvailable: NSDecimalNumber = NSDecimalNumber.zero
    var reaminPAmount: NSDecimalNumber = NSDecimalNumber.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.account = BaseData.instance.selectAccountById(id: BaseData.instance.getRecentAccountId())
        self.chainType = WUtils.getChainType(account!.account_base_chain)
        
        pageHolderVC = self.parent as? StepGenTxViewController
        cDenom = pageHolderVC.cDenom!
        mMarketID = pageHolderVC.mMarketID!
        
        self.loadingImg.onStartAnimation()
        self.onFetchCdpData()
        
        pAmountInput.delegate = self
    }
    
    override func enableUserInteraction() {
        self.btnCancel.isUserInteractionEnabled = true
        self.btnNext.isUserInteractionEnabled = true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if (text.contains(".") && string.contains(".") && range.length == 0) { return false }
        if (text.count == 0 && string.starts(with: ".")) { return false }
        if (text.contains(",") && string.contains(",") && range.length == 0) { return false }
        if (text.count == 0 && string.starts(with: ",")) { return false }
        if let index = text.range(of: ".")?.upperBound {
            if(text.substring(from: index).count > (pDpDecimal - 1) && range.length == 0) { return false }
        }
        if let index = text.range(of: ",")?.upperBound {
            if(text.substring(from: index).count > (pDpDecimal - 1) && range.length == 0) { return false }
        }
        return true
    }
    
    @IBAction func AmountChanged(_ sender: AmountInputTextField) {
        guard let text = sender.text?.trimmingCharacters(in: .whitespaces) else {
            sender.layer.borderColor = UIColor.init(hexString: "f31963").cgColor
            return
        }
        if (text.count == 0) {
            sender.layer.borderColor = UIColor.white.cgColor
            return
        }
        let userInput = WUtils.stringToDecimal(text)
        if (text.count > 1 && userInput == NSDecimalNumber.zero) {
            sender.layer.borderColor = UIColor.init(hexString: "f31963").cgColor
            return
        }
        let userInputAmount = userInput.multiplying(byPowerOf10: pDpDecimal)
        if ((userInputAmount.compare(pMinAmount).rawValue < 0 || userInputAmount.compare(pMaxAmount).rawValue > 0) &&
            userInputAmount != pAllAmount) {
            sender.layer.borderColor = UIColor.init(hexString: "f31963").cgColor
            return
        }
        sender.layer.borderColor = UIColor.white.cgColor
        onUpdateNextBtn()
    }
    
    
    @IBAction func onClickClear(_ sender: UIButton) {
        pAmountInput.text = ""
        onUpdateNextBtn()
    }
    
    @IBAction func onClick1_3(_ sender: UIButton) {
        if (pMaxAmount.compare(NSDecimalNumber.zero).rawValue > 0) {
            var calValue = pMaxAmount.dividing(by: NSDecimalNumber.init(string: "3"), withBehavior: WUtils.handler0Down)
            if (calValue.compare(pMinAmount).rawValue < 0) {
                calValue = pMinAmount
                self.onShowToast(NSLocalizedString("error_less_than_min_principal", comment: ""))
            }
            calValue = calValue.multiplying(byPowerOf10: -pDpDecimal, withBehavior: WUtils.getDivideHandler(pDpDecimal))
            pAmountInput.text = WUtils.DecimalToLocalString(calValue, pDpDecimal)
            AmountChanged(pAmountInput)
        } else {
            self.onShowToast(NSLocalizedString("str_cannot_repay_partially", comment: ""))
        }
    }
    
    @IBAction func onClick2_3(_ sender: UIButton) {
        if (pMaxAmount.compare(NSDecimalNumber.zero).rawValue > 0) {
            var calValue = pMaxAmount.multiplying(by: NSDecimalNumber.init(string: "2")).dividing(by: NSDecimalNumber.init(string: "3"), withBehavior: WUtils.handler0Down)
            if (calValue.compare(pMinAmount).rawValue < 0) {
                calValue = pMinAmount
                self.onShowToast(NSLocalizedString("error_less_than_min_principal", comment: ""))
            }
            calValue = calValue.multiplying(byPowerOf10: -pDpDecimal, withBehavior: WUtils.getDivideHandler(pDpDecimal))
            pAmountInput.text = WUtils.DecimalToLocalString(calValue, pDpDecimal)
            AmountChanged(pAmountInput)
        } else {
            self.onShowToast(NSLocalizedString("str_cannot_repay_partially", comment: ""))
        }
    }
    
    @IBAction func onClickMax(_ sender: UIButton) {
        if (pMaxAmount.compare(NSDecimalNumber.zero).rawValue > 0) {
            let maxValue = pMaxAmount.multiplying(byPowerOf10: -pDpDecimal, withBehavior: WUtils.getDivideHandler(pDpDecimal))
            pAmountInput.text = WUtils.DecimalToLocalString(maxValue, pDpDecimal)
            AmountChanged(pAmountInput)
        } else {
            self.onShowToast(NSLocalizedString("str_cannot_repay_partially", comment: ""))
        }
    }
    
    @IBAction func onClickAll(_ sender: UIButton) {
        if (pAllAmount.compare(NSDecimalNumber.zero).rawValue > 0) {
            let maxValue = pAllAmount.multiplying(byPowerOf10: -pDpDecimal, withBehavior: WUtils.getDivideHandler(pDpDecimal))
            pAmountInput.text = WUtils.DecimalToLocalString(maxValue, pDpDecimal)
            AmountChanged(pAmountInput)
        } else {
            self.onShowToast(String(format: NSLocalizedString("str_cannot_repay_all", comment: ""), self.pDenom.uppercased()))
        }
    }
    
    @IBAction func onClickCancel(_ sender: UIButton) {
        self.btnCancel.isUserInteractionEnabled = false
        self.btnNext.isUserInteractionEnabled = false
        pageHolderVC.onBeforePage()
    }
    
    @IBAction func onClickNext(_ sender: UIButton) {
        if (isValiadPAmount()) {
            view.endEditing(true)
            let popupVC = RiskCheckPopupViewController(nibName: "RiskCheckPopupViewController", bundle: nil)
            popupVC.type = popupVC.RISK_POPUP_CHANGE
            popupVC.cDenom = self.cDenom
            popupVC.DNcurrentPrice = self.currentPrice
            popupVC.DNbeforeLiquidationPrice = self.beforeLiquidationPrice
            popupVC.DNbeforeRiskRate = self.beforeRiskRate
            popupVC.DNafterLiquidationPrice = self.afterLiquidationPrice
            popupVC.DNafterRiskRate = self.afterRiskRate
            
            let cardPopup = SBCardPopupViewController(contentViewController: popupVC)
            cardPopup.resultDelegate = self
            cardPopup.show(onViewController: self)

        } else {
            self.onShowToast(NSLocalizedString("error_amount", comment: ""))
        }
    }
    
    func SBCardPopupResponse(type:Int, result: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300), execute: {
            if(result == 10) {
                let pCoin = Coin.init(self.pDenom, self.toPAmount.stringValue)
                self.pageHolderVC.mPayment = pCoin
                
                self.pageHolderVC.currentPrice = self.currentPrice
                self.pageHolderVC.beforeLiquidationPrice = self.beforeLiquidationPrice
                self.pageHolderVC.afterLiquidationPrice = self.afterLiquidationPrice
                self.pageHolderVC.beforeRiskRate = self.beforeRiskRate
                self.pageHolderVC.afterRiskRate = self.afterRiskRate
                self.pageHolderVC.pDenom = self.pDenom
                self.pageHolderVC.totalLoanAmount = self.reaminPAmount

                self.btnCancel.isUserInteractionEnabled = false
                self.btnNext.isUserInteractionEnabled = false
                self.pageHolderVC.onNextPage()
            }
        })
    }
    
    func isValiadPAmount() -> Bool {
        let text = pAmountInput.text?.trimmingCharacters(in: .whitespaces)
        if (text == nil || text!.count == 0) { return false }
        let userInput = WUtils.stringToDecimal(text!)
        if (userInput == NSDecimalNumber.zero) { return false }
        let userInputAmount = userInput.multiplying(byPowerOf10: pDpDecimal)
        if ((userInputAmount.compare(pMinAmount).rawValue < 0 || userInputAmount.compare(pMaxAmount).rawValue > 0) &&
            userInputAmount != pAllAmount) {
            return false
        }
        
        toPAmount = userInputAmount
        reaminPAmount = mMyCdps!.result.cdp.getEstimatedTotalDebt(cParam!).subtracting(toPAmount)
        let collateralAmount = mMyCdps!.result.getTotalCollateralAmount().multiplying(byPowerOf10: -cDpDecimal)
        let rawDebtAmount = reaminPAmount.multiplying(by: cParam!.getLiquidationRatio()).multiplying(byPowerOf10: -pDpDecimal)
        afterLiquidationPrice = rawDebtAmount.dividing(by: collateralAmount, withBehavior: WUtils.getDivideHandler(pDpDecimal))
        afterRiskRate = NSDecimalNumber.init(string: "100").subtracting(currentPrice.subtracting(afterLiquidationPrice).multiplying(byPowerOf10: 2).dividing(by: currentPrice, withBehavior: WUtils.handler2Down))
        
        if (SHOW_LOG) {
            print("currentPrice ", currentPrice)
            print("afterLiquidationPrice ", afterLiquidationPrice)
            print("afterRiskRate ", afterRiskRate)
        }
        return true
    }
    
    func onUpdateNextBtn() {
        if (!isValiadPAmount()) {
            btnNext.backgroundColor = UIColor.clear
            btnNext.setTitle(NSLocalizedString("tx_next", comment: ""), for: .normal)
            btnNext.setTitleColor(COLOR_PHOTON, for: .normal)
            btnNext.layer.borderWidth = 1.0
            afterSafeRate.isHidden = true
            afterSafeTxt.isHidden = true
        } else {
            btnNext.setTitleColor(UIColor.black, for: .normal)
            btnNext.layer.borderWidth = 0.0
            if (afterRiskRate.doubleValue <= 50) {
                btnNext.backgroundColor = COLOR_CDP_SAFE
                btnNext.setTitle("SAFE", for: .normal)
                if (reaminPAmount == NSDecimalNumber.zero) {
                    btnNext.setTitle("Repay All", for: .normal)
                }
                
            } else if (afterRiskRate.doubleValue < 80) {
                btnNext.backgroundColor = COLOR_CDP_STABLE
                btnNext.setTitle("STABLE", for: .normal)
                
            } else {
                btnNext.backgroundColor = COLOR_CDP_DANGER
                btnNext.setTitle("DANGER", for: .normal)
            }
            WUtils.showRiskRate2(afterRiskRate, afterSafeRate, afterSafeTxt)
            afterSafeRate.isHidden = false
            afterSafeTxt.isHidden = false
        }
    }
    
    
    
    
    
    
    
    var mFetchCnt = 0
    func onFetchCdpData() {
        self.mFetchCnt = 4
        onFetchCdpParam()
        onFetchKavaPrice(self.mMarketID)
        onFetchOwenCdp(account!, self.cDenom)
        onFetchCdpDeposit(account!, self.cDenom)
    }
    
    func onFetchFinished() {
        self.mFetchCnt = self.mFetchCnt - 1
        if (mFetchCnt <= 0) {
            if (cParam == nil || mPrice == nil || mMyCdps == nil) {
                print("ERROR");
                return
            }
            pDenom = cParam!.getpDenom()

            cDpDecimal = WUtils.getKavaCoinDecimal(cDenom)
            pDpDecimal = WUtils.getKavaCoinDecimal(pDenom)
            currentPrice = NSDecimalNumber.init(string: mPrice?.result.price)
            
            pAvailable = account!.getTokenBalance(pDenom)
            pAllAmount = mMyCdps!.result.cdp.getEstimatedTotalDebt(cParam!)
            if (SHOW_LOG) {
                print("pAvailable ", pAvailable)
                print("pAllAmount ", pAllAmount)
            }
            
            let debtFloor = NSDecimalNumber.init(string: cdpParam!.result.debt_param?.debt_floor)
            let rawDebtAmount = mMyCdps!.result.cdp.getRawPrincipalAmount()
            
            pMaxAmount = rawDebtAmount.subtracting(debtFloor)
            pMinAmount = NSDecimalNumber.one
            if (SHOW_LOG) {
                print("debtFloor ", debtFloor)
                print("rawDebtAmount ", rawDebtAmount)
                print("pMaxAmount ", pMaxAmount)
                print("pMinAmount ", pMinAmount)
            }
            
            
            if (pAllAmount.compare(pAvailable).rawValue > 0) {
                // now disable to repay all
                pAllAmount = NSDecimalNumber.zero
            }
            if (rawDebtAmount.compare(debtFloor).rawValue < 0) {
                // now disbale to partically repay
                pMaxAmount = NSDecimalNumber.zero
                pMinAmount = NSDecimalNumber.zero
            } else {
                if (pMaxAmount.compare(pAvailable).rawValue > 0) {
                    pMaxAmount = pAvailable
                }
            }
            
            if (SHOW_LOG) {
                print("F pAllAmount ", pAllAmount)
                print("F pMaxAmount ", pMaxAmount)
                print("F pMinAmount ", pMinAmount)
            }
            
            if (pAllAmount.compare(NSDecimalNumber.zero).rawValue > 0) {
                pAllLabel.attributedText = WUtils.displayAmount2(pAllAmount.stringValue, pAllLabel.font!, pDpDecimal, pDpDecimal)
            } else {
                pAllTitle.isHidden = true
                pAllLabel.isHidden = true
                pAllDenom.isHidden = true
                pDisableAll.isHidden = false
                pDisableAll.text = String(format: NSLocalizedString("str_cannot_repay_all", comment: ""), self.pDenom.uppercased())
            }
            if (pMaxAmount.compare(NSDecimalNumber.zero).rawValue > 0 && pMinAmount.compare(NSDecimalNumber.zero).rawValue > 0) {
                pParticalMaxLabel.attributedText = WUtils.displayAmount2(pMaxAmount.stringValue, pParticalMaxLabel.font!, pDpDecimal, pDpDecimal)
                pParticalMinLabel.attributedText = WUtils.displayAmount2(pMinAmount.stringValue, pParticalMinLabel.font!, pDpDecimal, pDpDecimal)
            } else {
                pParticalTitle.isHidden = true
                pParticalMinLabel.isHidden = true
                pParticalDashLabel.isHidden = true
                pParticalMaxLabel.isHidden = true
                pParticalDenom.isHidden = true
                pDisablePartical.isHidden = false
            }
            
            beforeLiquidationPrice = mMyCdps!.result.getLiquidationPrice(cDenom, pDenom, cParam!)
            beforeRiskRate = NSDecimalNumber.init(string: "100").subtracting(currentPrice.subtracting(beforeLiquidationPrice).multiplying(byPowerOf10: 2).dividing(by: currentPrice, withBehavior: WUtils.handler2Down))
            WUtils.showRiskRate2(beforeRiskRate, beforeSafeRate, beforeSafeTxt)

            if (SHOW_LOG) {
                print("currentPrice ", currentPrice)
                print("beforeLiquidationPrice ", beforeLiquidationPrice)
                print("beforeRiskRate ", beforeRiskRate)
            }

            pDenomLabel.text = pDenom.uppercased()
            pParticalDenom.text = pDenom.uppercased()
            pAllDenom.text = pDenom.uppercased()
            Alamofire.request(KAVA_COIN_IMG_URL + pDenom + ".png", method: .get).responseImage { response  in
                guard let image = response.result.value else { return }
                self.pDenomImg.image = image
            }
            self.loadingImg.onStopAnimation()
            self.loadingImg.isHidden = true
        }
    }
    
    
    func onFetchCdpParam() {
        var url: String?
        if (chainType == ChainType.KAVA_MAIN) {
            url = KAVA_CDP_PARAM
        } else if (chainType == ChainType.KAVA_TEST) {
            url = KAVA_TEST_CDP_PARAM
        }
        let request = Alamofire.request(url!, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:]);
        request.responseJSON { (response) in
            switch response.result {
            case .success(let res):
                guard let responseData = res as? NSDictionary,
                    let _ = responseData.object(forKey: "height") as? String else {
                        self.onFetchFinished()
                        return
                }
                self.cdpParam = CdpParam.init(responseData)
                self.cParam = self.cdpParam!.result.getcParam(self.cDenom)
                
            case .failure(let error):
                if (SHOW_LOG) { print("onFetchCdpParam ", error) }
            }
            self.onFetchFinished()
        }
    }
    
    func onFetchKavaPrice(_ market:String) {
        var url: String?
        if (chainType == ChainType.KAVA_MAIN) {
            url = KAVA_TOKEN_PRICE + market
        } else if (chainType == ChainType.KAVA_TEST) {
            url = KAVA_TEST_TOKEN_PRICE + market
        }
        let request = Alamofire.request(url!, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:]);
        request.responseJSON { (response) in
            switch response.result {
            case .success(let res):
                guard let responseData = res as? NSDictionary,
                    let _ = responseData.object(forKey: "height") as? String else {
                        self.onFetchFinished()
                        return
                }
                self.mPrice = KavaTokenPrice.init(responseData)
                
            case .failure(let error):
                if (SHOW_LOG) { print("onFetchKavaPrice ", market , " ", error) }
            }
            self.onFetchFinished()
        }
    }
    
    func onFetchOwenCdp(_ account:Account, _ denom:String) {
        var url: String?
        if (chainType == ChainType.KAVA_MAIN) {
            url = KAVA_CDP_OWEN + account.account_address + "/" + denom
        } else if (chainType == ChainType.KAVA_TEST) {
            url = KAVA_TEST_CDP_OWEN + account.account_address + "/" + denom
        }
        let request = Alamofire.request(url!, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:]);
        request.responseJSON { (response) in
            switch response.result {
            case .success(let res):
                guard let responseData = res as? NSDictionary,
                    let _ = responseData.object(forKey: "height") as? String,
                    responseData.object(forKey: "result") != nil else {
                        self.onFetchFinished()
                        return
                }
                self.mMyCdps = CdpOwen.init(responseData)
                
            case .failure(let error):
                if (SHOW_LOG) { print("onFetchOwenCdp ", error) }
            }
            self.onFetchFinished()
        }
    }
    
    func onFetchCdpDeposit(_ account:Account, _ denom:String) {
        var url: String?
        if (chainType == ChainType.KAVA_MAIN) {
            url = KAVA_CDP_DEPOSIT + account.account_address + "/" + denom
        } else if (chainType == ChainType.KAVA_TEST) {
            url = KAVA_TEST_CDP_DEPOSIT + account.account_address + "/" + denom
        }
        let request = Alamofire.request(url!, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:]);
        request.responseJSON { (response) in
            switch response.result {
            case .success(let res):
                guard let responseData = res as? NSDictionary,
                    let _ = responseData.object(forKey: "height") as? String,
                    responseData.object(forKey: "result") != nil else {
                        self.onFetchFinished()
                        return
                }
                self.mMyCdpDeposit = CdpDeposits.init(responseData)
                
            case .failure(let error):
                if (SHOW_LOG) { print("onFetchCdpDeposit ", error) }
            }
            self.onFetchFinished()
        }
    }
}
